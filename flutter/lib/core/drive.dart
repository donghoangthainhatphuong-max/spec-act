/// Minimal Google Drive v3 REST client (device <-> Google only), port of src/services/drive.js.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const mimeFolder = 'application/vnd.google-apps.folder';
const mimeShortcut = 'application/vnd.google-apps.shortcut';
const _api = 'https://www.googleapis.com/drive/v3';
const _upload = 'https://www.googleapis.com/upload/drive/v3';

class DriveError implements Exception {
  DriveError(this.status, [this.reason, this.message]);
  final int status;
  final String? reason;
  final String? message;
  bool get notFound => status == 404;
  bool get forbidden => status == 403 || status == 401;
  @override
  String toString() => 'DriveError($status, $reason, $message)';
}

/// Escape a literal for a Drive `q` expression.
String qs(String v) => "'${v.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

class DriveClient {
  DriveClient({
    required this.getToken,
    this.onUnauthorized,
    http.Client? client,
    this.concurrency = 10,
  }) : _http = client ?? http.Client();
  final Future<String> Function() getToken;
  final Future<String> Function()? onUnauthorized;
  final http.Client _http;
  final int concurrency;
  int _active = 0;
  final _queue = <Completer<void>>[];

  /// A high-priority job (the photo someone just opened) jumps ahead of queued thumbnails.
  Future<T> _limited<T>(Future<T> Function() fn, {bool high = false}) async {
    while (_active >= concurrency) {
      final c = Completer<void>();
      high ? _queue.insert(0, c) : _queue.add(c);
      await c.future;
    }
    _active++;
    try {
      return await fn();
    } finally {
      _active--;
      if (_queue.isNotEmpty) _queue.removeAt(0).complete();
    }
  }

  /// Returns the decoded JSON (or null for 204); with [raw] the raw response.
  Future<dynamic> request(
    String url, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Object? body,
    bool raw = false,
    int retries = 3,
    bool high = false,
  }) {
    return _limited(high: high, () async {
      var token = await getToken();
      var refreshed = false;
      for (var attempt = 0; ; attempt++) {
        http.Response res;
        try {
          final req = http.Request(method, Uri.parse(url))
            ..headers.addAll({...headers, 'Authorization': 'Bearer $token'});
          if (body is String) req.body = body;
          if (body is List<int>) req.bodyBytes = body;
          res = await http.Response.fromStream(await _http.send(req));
        } catch (_) {
          if (attempt < retries) {
            await Future.delayed(Duration(milliseconds: 400 * (1 << attempt)));
            continue;
          }
          throw DriveError(0, 'network', 'network error');
        }
        if (res.statusCode == 401 && !refreshed && onUnauthorized != null) {
          refreshed = true;
          token = await onUnauthorized!();
          continue;
        }
        var retry = res.statusCode == 429 || res.statusCode >= 500;
        if (res.statusCode == 403 && attempt < retries) {
          retry = RegExp(
            'rateLimitExceeded|userRateLimitExceeded',
          ).hasMatch(_reason(res) ?? '');
        }
        if (retry && attempt < retries) {
          await Future.delayed(
            Duration(
              milliseconds: 500 * (1 << attempt) + Random().nextInt(250),
            ),
          );
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          Map<String, dynamic>? j;
          try {
            j =
                jsonDecode(utf8.decode(res.bodyBytes))['error']
                    as Map<String, dynamic>?;
          } catch (_) {}
          throw DriveError(
            res.statusCode,
            (j?['errors'] as List?)?.firstOrNull?['reason'] as String? ??
                j?['status'] as String?,
            j?['message'] as String?,
          );
        }
        if (raw) return res;
        if (res.statusCode == 204 || res.bodyBytes.isEmpty) return null;
        final ct = res.headers['content-type'] ?? '';
        return ct.contains('json')
            ? jsonDecode(utf8.decode(res.bodyBytes))
            : utf8.decode(res.bodyBytes);
      }
    });
  }

  String? _reason(http.Response r) {
    try {
      return (jsonDecode(
            utf8.decode(r.bodyBytes),
          )['error']['errors'][0]['reason'])
          as String?;
    } catch (_) {
      return null;
    }
  }

  static String _enc(String s) => Uri.encodeComponent(s);
  static const _jsonHeaders = {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> about() async => Map<String, dynamic>.from(
    await request(
      '$_api/about?fields=${_enc('user(displayName,emailAddress,photoLink),storageQuota(limit,usage,usageInDrive)')}',
    ),
  );

  Future<List<Map<String, dynamic>>> list({
    required String q,
    String fields = 'id,name,mimeType,modifiedTime,properties',
    int pageSize = 200,
    String? orderBy,
  }) async {
    final out = <Map<String, dynamic>>[];
    String? token;
    do {
      final p = {
        'q': q,
        'pageSize': '$pageSize',
        'fields': 'nextPageToken,files($fields)',
        'spaces': 'drive',
        if (orderBy != null) 'orderBy': orderBy,
        if (token != null) 'pageToken': token,
      };
      final j =
          await request('$_api/files?${Uri(queryParameters: p).query}')
              as Map<String, dynamic>;
      out.addAll(
        ((j['files'] as List?) ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      token = j['nextPageToken'] as String?;
    } while (token != null);
    return out;
  }

  Future<Map<String, dynamic>> get(
    String id, [
    String fields = 'id,name,mimeType,modifiedTime,properties',
  ]) async => Map<String, dynamic>.from(
    await request('$_api/files/${_enc(id)}?fields=${_enc(fields)}'),
  );

  Future<Map<String, dynamic>> createFolder(
    String name,
    String? parentId, [
    Map<String, String>? properties,
  ]) async => Map<String, dynamic>.from(
    await request(
      '$_api/files?fields=${_enc('id,name,properties')}',
      method: 'POST',
      headers: _jsonHeaders,
      body: jsonEncode({
        'name': name,
        'mimeType': mimeFolder,
        if (parentId != null) 'parents': [parentId],
        if (properties != null) 'properties': properties,
      }),
    ),
  );

  Future<Map<String, dynamic>> updateMeta(
    String id,
    Map<String, dynamic> body, {
    String fields = 'id,name,properties,modifiedTime',
  }) async => Map<String, dynamic>.from(
    await request(
      '$_api/files/${_enc(id)}?fields=${_enc(fields)}',
      method: 'PATCH',
      headers: _jsonHeaders,
      body: jsonEncode(body),
    ),
  );

  Future<void> trash(String id) => updateMeta(id, {'trashed': true});

  /// Multipart upload (small files).
  Future<Map<String, dynamic>> createFile({
    required String name,
    String? parentId,
    required String mimeType,
    required List<int> data,
  }) async {
    final meta = jsonEncode({
      'name': name,
      if (parentId != null) 'parents': [parentId],
      'mimeType': mimeType,
    });
    final boundary =
        'specact${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final b = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n--$boundary\r\nContent-Type: $mimeType\r\n\r\n',
        ),
      )
      ..add(data)
      ..add(utf8.encode('\r\n--$boundary--'));
    return Map<String, dynamic>.from(
      await request(
        '$_upload/files?uploadType=multipart&fields=${_enc('id,name,mimeType,modifiedTime,version')}',
        method: 'POST',
        headers: {'Content-Type': 'multipart/related; boundary=$boundary'},
        body: b.toBytes(),
      ),
    );
  }

  /// Resumable upload for large files (video).
  Future<Map<String, dynamic>> createFileLarge({
    required String name,
    String? parentId,
    required String mimeType,
    required Uint8List data,
  }) async {
    if (data.length <= 4 * 1024 * 1024)
      return createFile(
        name: name,
        parentId: parentId,
        mimeType: mimeType,
        data: data,
      );
    final init =
        await request(
              '$_upload/files?uploadType=resumable&fields=${_enc('id,name,mimeType,modifiedTime,version')}',
              method: 'POST',
              raw: true,
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'X-Upload-Content-Type': mimeType,
              },
              body: jsonEncode({
                'name': name,
                if (parentId != null) 'parents': [parentId],
                'mimeType': mimeType,
              }),
            )
            as http.Response;
    final session = init.headers['location'];
    if (session == null)
      return createFile(
        name: name,
        parentId: parentId,
        mimeType: mimeType,
        data: data,
      );
    final res = await request(
      session,
      method: 'PUT',
      headers: {'Content-Type': mimeType},
      body: data,
      retries: 1,
    );
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> createJson(
    String name,
    String parentId,
    Object value,
  ) => createFile(
    name: name,
    parentId: parentId,
    mimeType: 'application/json',
    data: utf8.encode(jsonEncode(value)),
  );

  Future<void> updateContent(
    String id,
    List<int> data, [
    String mimeType = 'application/json',
  ]) => request(
    '$_upload/files/${_enc(id)}?uploadType=media&fields=${_enc('id,modifiedTime,version')}',
    method: 'PATCH',
    headers: {'Content-Type': mimeType},
    body: data,
  );

  Future<void> updateJson(String id, Object value) =>
      updateContent(id, utf8.encode(jsonEncode(value)));

  Future<Map<String, dynamic>> downloadJson(String id) async {
    final res =
        await request('$_api/files/${_enc(id)}?alt=media', raw: true)
            as http.Response;
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map,
    );
  }

  Future<Uint8List> downloadBytes(String id, {bool high = false}) async =>
      ((await request(
                '$_api/files/${_enc(id)}?alt=media',
                raw: true,
                high: high,
              ))
              as http.Response)
          .bodyBytes;

  /* ---------- permissions ---------- */
  Future<List<Map<String, dynamic>>> listPermissions(String fileId) async {
    final j =
        await request(
              '$_api/files/${_enc(fileId)}/permissions?fields=${_enc('permissions(id,type,role,emailAddress,displayName)')}&pageSize=100',
            )
            as Map;
    return ((j['permissions'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> addPermission(
    String fileId, {
    String? email,
    required String role,
    String type = 'user',
    bool notify = false,
  }) async {
    Future<void> attempt(bool send) async {
      final q = Uri(
        queryParameters: {
          'sendNotificationEmail': '$send',
          'fields': 'id,type,role,emailAddress,displayName',
        },
      ).query;
      final body = type == 'anyone'
          ? {'type': type, 'role': role, 'allowFileDiscovery': false}
          : {'type': type, 'role': role, 'emailAddress': email};
      await request(
        '$_api/files/${_enc(fileId)}/permissions?$q',
        method: 'POST',
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
    }

    try {
      await attempt(notify);
    } on DriveError catch (e) {
      // addresses without a Google account can only be invited by e-mail
      if (!notify &&
          e.status == 400 &&
          RegExp(
            'notif|invalid.*sharing|invalidSharingRequest',
            caseSensitive: false,
          ).hasMatch('${e.reason} ${e.message}')) {
        await attempt(true);
      } else {
        rethrow;
      }
    }
  }

  Future<void> updatePermission(
    String fileId,
    String permissionId,
    String role,
  ) => request(
    '$_api/files/${_enc(fileId)}/permissions/${_enc(permissionId)}?fields=id,role',
    method: 'PATCH',
    headers: _jsonHeaders,
    body: jsonEncode({'role': role}),
  );

  Future<void> removePermission(String fileId, String permissionId) => request(
    '$_api/files/${_enc(fileId)}/permissions/${_enc(permissionId)}',
    method: 'DELETE',
  );
}
