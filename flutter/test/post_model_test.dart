import 'package:flutter_test/flutter_test.dart';
import 'package:specact/core/post_model.dart';

void main() {
  test('hostile attachment keeps no executable type', () {
    final m = publicMedia({'id': 'abc123', 'mime': 'text/html', 'name': 'x.html', 'kind': 'image'});
    expect(m['kind'], 'file');
    expect(m['mime'], 'application/octet-stream');
    expect(publicMedia({'id': 'a1', 'mime': 'image/svg+xml'})['mime'], 'application/octet-stream');
  });

  test('bad ids and spoofing names are cleaned', () {
    expect(publicMedia({'id': '../../x?alt=media', 'mime': 'image/jpeg'})['id'], '');
    expect(publicMedia({'id': 'a1', 'thumb': null})['thumb'], isNull);
    expect(cleanName('evil\u202Efdp.exe\n'), 'evilfdp.exe');
    expect(cleanName('a/b\\c'), 'a_b_c');
  });

  test('post doc round trip and mentions', () async {
    final doc = await buildPostDoc(
      id: 'p1', owner: {'email': 'A@x.com', 'name': 'A'}, createdAt: 1, updatedAt: 1, text: 'hi @bob@y.com', media: [], mentions: extractMentions('hi @bob@y.com'),
      audience: {'bob@y.com': 'comment', 'a@x.com': 'view'}, linkShare: false, commentMode: 'weird',
    );
    final post = await openPostDoc(doc, null);
    expect(post['audience'], {'bob@y.com': 'comment'});
    expect(post['commentMode'], 'shared');
    expect(post['mentions'], ['bob@y.com']);
    expect(folderNameFor(0, 'ab'), '__S.P.E.C.T.A.C.T__ 1970-01-01_ab');
  });
}
