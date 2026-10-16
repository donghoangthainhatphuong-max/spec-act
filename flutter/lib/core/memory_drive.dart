import 'dart:convert';
import 'dart:typed_data';

import 'drive.dart';

class FNode {
  FNode(this.id, this.name, this.mime, this.parent, this.owner, {Map<String, String>? props, this.data}) : props = props ?? {};
  final String id;
  String name;
  final String mime;
  String? parent;
  final String owner;
  final Map<String, String> props;
  Uint8List? data;
  bool trashed = false;
  final perms = <Map<String, dynamic>>[];
}

class MemoryStore {
  final nodes = <String, FNode>{};
  int _n = 0;
  String nextId() => 'f${++_n}';
}

/// In-memory Google Drive for one user (several clients can share a MemoryStore). Used by the demo mode and the tests.
class MemoryDrive extends DriveClient {
  MemoryDrive(this.store, this.user) : super(getToken: () async => 't');
  final MemoryStore store;
  final String user;

  bool _canSee(FNode n) {
    if (n.owner == user) return true;
    for (FNode? c = n; c != null; c = c.parent == null ? null : store.nodes[c.parent]) {
      if (c.perms.any((p) => p['emailAddress'] == user || p['type'] == 'anyone')) return true;
    }
    return false;
  }

  bool _canEdit(FNode n) {
    if (n.owner == user) return true;
    for (FNode? c = n; c != null; c = c.parent == null ? null : store.nodes[c.parent]) {
      if (c.perms.any((p) => (p['emailAddress'] == user || p['type'] == 'anyone') && p['role'] == 'writer')) return true;
    }
    return false;
  }

  Map<String, dynamic> _json(FNode n) => {
        'id': n.id, 'name': n.name, 'mimeType': n.mime, 'properties': n.props.isEmpty ? null : Map.of(n.props), 'modifiedTime': '2026-01-01T00:00:00Z', 'trashed': n.trashed,
        'owners': [{'emailAddress': n.owner, 'displayName': n.owner.split('@').first}],
        'capabilities': {'canEdit': _canEdit(n)},
      };

  FNode _need(String id) {
    final n = store.nodes[id];
    if (n == null || !_canSee(n)) throw DriveError(404, 'notFound');
    return n;
  }

  FNode _add(String name, String mime, String? parent, {Map<String, String>? props, Uint8List? data}) {
    final n = FNode(store.nextId(), name, mime, parent == 'root' ? null : parent, user, props: props, data: data);
    store.nodes[n.id] = n;
    return n;
  }

  @override
  Future<List<Map<String, dynamic>>> list({required String q, String fields = '', int pageSize = 200, String? orderBy}) async {
    var items = store.nodes.values.where((n) => !n.trashed && _canSee(n));
    final name = RegExp(r"name = '((?:[^'\\]|\\.)*)'").firstMatch(q)?.group(1)?.replaceAll(r"\'", "'");
    final parent = RegExp(r"'([^']+)' in parents").firstMatch(q)?.group(1);
    if (name != null) items = items.where((n) => n.name == name);
    if (parent != null) items = items.where((n) => (n.parent ?? 'root') == parent && (parent != 'root' || n.owner == user));
    if (q.contains('mimeType = ')) items = items.where((n) => n.mime == mimeFolder);
    if (q.contains('sharedWithMe = true')) items = items.where((n) => n.owner != user);
    final pm = RegExp(r"key='(\w+)' and value='(\w+)'").firstMatch(q);
    if (pm != null) items = items.where((n) => n.props[pm.group(1)] == pm.group(2));
    return items.map(_json).toList();
  }

  @override
  Future<Map<String, dynamic>> get(String id, [String fields = '']) async => _json(_need(id));

  @override
  Future<Map<String, dynamic>> createFolder(String name, String? parentId, [Map<String, String>? properties]) async => _json(_add(name, mimeFolder, parentId, props: properties));

  @override
  Future<Map<String, dynamic>> updateMeta(String id, Map<String, dynamic> body, {String fields = ''}) async {
    final n = _need(id);
    (body['properties'] as Map?)?.forEach((k, v) => n.props['$k'] = '$v');
    if (body['trashed'] == true) n.trashed = true;
    return _json(n);
  }

  @override
  Future<void> trash(String id) => updateMeta(id, {'trashed': true});

  @override
  Future<Map<String, dynamic>> createFile({required String name, String? parentId, required String mimeType, required List<int> data}) async =>
      _json(_add(name, mimeType, parentId, data: Uint8List.fromList(data)));

  @override
  Future<Map<String, dynamic>> createFileLarge({required String name, String? parentId, required String mimeType, required Uint8List data}) => createFile(name: name, parentId: parentId, mimeType: mimeType, data: data);

  @override
  Future<Map<String, dynamic>> createJson(String name, String parentId, Object value) => createFile(name: name, parentId: parentId, mimeType: 'application/json', data: utf8.encode(jsonEncode(value)));

  @override
  Future<void> updateContent(String id, List<int> data, [String mimeType = 'application/json']) async {
    final n = _need(id);
    if (!_canEdit(n)) throw DriveError(403, 'forbidden');
    n.data = Uint8List.fromList(data);
  }

  @override
  Future<void> updateJson(String id, Object value) => updateContent(id, utf8.encode(jsonEncode(value)));

  @override
  Future<Map<String, dynamic>> downloadJson(String id) async => Map<String, dynamic>.from(jsonDecode(utf8.decode(_need(id).data!)) as Map);

  @override
  Future<Uint8List> downloadBytes(String id, {bool high = false}) async {
    downloads.add(id);
    return _need(id).data!;
  }

  /// Ids downloaded so far (tests check that a photo is fetched only once).
  final downloads = <String>[];

  @override
  Future<Map<String, dynamic>> about() async => {'user': {'emailAddress': user, 'displayName': user.split('@').first}, 'storageQuota': {'usage': '1048576'}};

  @override
  Future<List<Map<String, dynamic>>> listPermissions(String fileId) async => _need(fileId).perms.map((p) => Map<String, dynamic>.from(p)).toList();

  @override
  Future<void> addPermission(String fileId, {String? email, required String role, String type = 'user', bool notify = false}) async {
    final n = _need(fileId);
    n.perms.add({'id': 'p${store.nextId()}', 'type': type, 'role': role, 'emailAddress': email});
  }

  @override
  Future<void> updatePermission(String fileId, String permissionId, String role) async => _need(fileId).perms.firstWhere((p) => p['id'] == permissionId)['role'] = role;

  @override
  Future<void> removePermission(String fileId, String permissionId) async => _need(fileId).perms.removeWhere((p) => p['id'] == permissionId);
}
