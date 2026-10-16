import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/auth.dart' as auth;
import 'core/config.dart';
import 'core/demo.dart';
import 'core/drive.dart';
import 'core/legal.dart';
import 'core/repo.dart';
import 'core/vault.dart';

enum Phase { boot, consent, setup, locked, signIn, ready }

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({Vault? vault}) : vault = vault ?? Vault();

  final Vault vault;
  Phase phase = Phase.boot;
  DriveRepo? repo;
  String? error; // i18n key of the last sign-in problem
  Map<String, String> account = {};
  /// Translator for the page the browser shows after Google redirects back (set by main).
  String Function(String key) translate = (k) => k;
  DateTime? _pausedAt;

  String? _clientId, _clientSecret, _refresh, _access;
  int _expiresAt = 0;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    consentOk = prefs.getString('terms.accepted') == termsVersion;
    // a brand-new device accepts on the page where it enters its Google keys; someone already set up gets the stand-alone screen
    final exists = await vault.exists();
    phase = exists ? (consentOk ? Phase.locked : Phase.consent) : Phase.setup;
    notifyListeners();
  }

  /// Whether the current Terms of Use and Privacy Policy have been accepted on this device.
  bool consentOk = false;

  /// Remembers the acceptance (used by the keys page of first-run setup, which has its own checkbox).
  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('terms.accepted', termsVersion);
    await prefs.setString('terms.acceptedAt', DateTime.now().toUtc().toIso8601String());
    consentOk = true;
  }

  Future<void> acceptTerms() async {
    await recordConsent();
    phase = await vault.exists() ? Phase.locked : Phase.setup;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (s == AppLifecycleState.resumed && _pausedAt != null) {
      final away = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (Config.autoLockMinutes > 0 && away.inMinutes >= Config.autoLockMinutes && vault.unlocked) lock();
    }
  }

  /* ---------- first run ---------- */
  Future<void> createVault({required String pin, required String clientId, String? clientSecret}) async {
    await vault.create(pin);
    await vault.set('creds', {'clientId': clientId.trim(), 'clientSecret': (clientSecret ?? '').trim()});
    _clientId = clientId.trim();
    _clientSecret = (clientSecret ?? '').trim();
    phase = Phase.signIn;
    notifyListeners();
  }

  /* ---------- unlock ---------- */
  Future<void> unlock(String pin) async {
    await vault.unlock(pin); // throws VaultError
    final creds = Map<String, dynamic>.from((await vault.get('creds', <String, dynamic>{})) as Map);
    _clientId = creds['clientId'] as String?;
    _clientSecret = creds['clientSecret'] as String?;
    final a = Map<String, dynamic>.from((await vault.get('auth', <String, dynamic>{})) as Map);
    _refresh = a['refreshToken'] as String?;
    account = Map<String, String>.from((a['account'] as Map?) ?? {});
    if (_refresh == null) {
      phase = Phase.signIn;
    } else {
      try {
        await _connect();
      } catch (_) {
        // offline or revoked: let the user retry from the sign-in screen
        phase = Phase.signIn;
      }
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    error = null;
    notifyListeners();
    try {
      final t = await auth.signIn(clientId: _clientId ?? '', clientSecret: _clientSecret, loginHint: account['email'], donePage: (title: translate('auth.doneTitle'), text: translate('auth.doneText'), button: translate('auth.doneButton')));
      _access = t.accessToken;
      _expiresAt = t.expiresAt;
      _refresh = t.refreshToken ?? _refresh;
      await _connect();
    } on auth.AuthError catch (e) {
      error = e.code == 'denied' ? 'error.generic' : 'error.generic';
    } catch (_) {
      error = 'error.generic';
    }
    notifyListeners();
  }

  Future<String> _token() async {
    if (_access == null || DateTime.now().millisecondsSinceEpoch > _expiresAt - 60000) await _refreshToken();
    return _access!;
  }

  Future<String> _refreshToken() async {
    final t = await auth.refresh(clientId: _clientId ?? '', clientSecret: _clientSecret, refreshToken: _refresh ?? '');
    _access = t.accessToken;
    _expiresAt = t.expiresAt;
    return _access!;
  }

  Future<void> _connect() async {
    final drive = DriveClient(getToken: _token, onUnauthorized: _refreshToken);
    final about = await drive.about();
    final user = about['user'] as Map<String, dynamic>;
    account = {'email': '${user['emailAddress']}', 'name': '${user['displayName'] ?? ''}'};
    await vault.set('auth', {'refreshToken': _refresh, 'account': account});
    repo = DriveRepo(drive: drive, email: account['email']!, name: account['name'], vault: vault);
    await repo!.restoreKeys();
    phase = Phase.ready;
  }

  /// Demo mode: sample data in memory, nothing is stored or sent anywhere.
  Future<void> startDemo() async {
    debugReady(await buildDemoRepo());
  }

  /// Test hook: skip Google sign-in and use the given repo.
  @visibleForTesting
  void debugReady(DriveRepo r) {
    repo = r;
    account = {'email': r.me.email, 'name': r.me.name};
    phase = Phase.ready;
    notifyListeners();
  }

  /* ---------- leaving ---------- */
  void lock() {
    vault.lock();
    repo = null;
    _access = null;
    phase = Phase.locked;
    notifyListeners();
  }

  Future<void> signOut() async {
    final t = _refresh ?? _access;
    if (t != null) unawaited(auth.revoke(t));
    await vault.remove('auth');
    _refresh = _access = null;
    repo = null;
    phase = Phase.signIn;
    notifyListeners();
  }

  Future<void> eraseEverything() async {
    await vault.wipe();
    repo = null;
    _refresh = _access = _clientId = _clientSecret = null;
    account = {};
    phase = Phase.setup;
    notifyListeners();
  }

  Future<void> changePin(String oldPin, String newPin) => vault.changePin(oldPin, newPin);

  /// Called when the vault wiped itself after too many wrong PINs.
  Future<void> wiped() async {
    phase = Phase.setup;
    notifyListeners();
  }
}
