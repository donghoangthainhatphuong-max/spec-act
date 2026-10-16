import 'dart:async';

import 'package:web/web.dart' as web;

typedef LoopbackResult = ({
  String redirect,
  String? code,
  String? state,
  String? error,
});

/// Web preview: sign in through a pop-up. Google redirects the pop-up back to this page's own address
/// (allowed for "Desktop app" OAuth clients, which accept any http://localhost:<port>), the opener reads the result and closes it.
typedef DonePage = ({String title, String text, String button});

Future<LoopbackResult> loopbackAuthorize(
  Uri Function(String redirect) buildUrl, {
  DonePage? page,
}) async {
  final origin = web.window.location.origin;
  final redirect = '$origin/';
  final popup = web.window.open(
    buildUrl(redirect).toString(),
    'specact-signin',
    'width=480,height=700',
  );
  if (popup == null) throw StateError('pop-up blocked');
  final done = Completer<LoopbackResult>();
  var ticks = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 400), (t) {
    try {
      // `closed` is blocked (and logged) while the pop-up sits on Google's cross-origin-isolated page, so ask rarely
      if (++ticks % 8 == 0 && popup.closed) {
        t.cancel();
        if (!done.isCompleted) done.completeError(StateError('closed'));
        return;
      }
      final u = Uri.parse(
        popup.location.href,
      ); // throws while the pop-up is still on Google's origin
      if (u.origin == origin &&
          (u.queryParameters.containsKey('code') ||
              u.queryParameters.containsKey('error'))) {
        t.cancel();
        popup.close();
        done.complete((
          redirect: redirect,
          code: u.queryParameters['code'],
          state: u.queryParameters['state'],
          error: u.queryParameters['error'],
        ));
      }
    } catch (_) {
      /* cross-origin: keep waiting */
    }
  });
  return done.future.timeout(
    const Duration(minutes: 10),
    onTimeout: () {
      timer.cancel();
      throw StateError('timeout');
    },
  );
}
