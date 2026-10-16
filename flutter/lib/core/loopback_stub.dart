/// Web has no local listener: Google sign-in is only available in the Android build.
typedef LoopbackResult = ({String redirect, String? code, String? state, String? error});

typedef DonePage = ({String title, String text, String button});

Future<LoopbackResult> loopbackAuthorize(Uri Function(String redirect) buildUrl, {DonePage? page}) async => throw UnsupportedError('sign-in needs the Android app');
