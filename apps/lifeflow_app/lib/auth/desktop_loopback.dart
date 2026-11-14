// Windows OAuth redirect capture on a loopback port (spike S-03a).
// Binds 127.0.0.1 only, serves exactly the /callback redirect, returns the
// authorization code. The SDK owns PKCE + state, so state is NOT validated
// here (doing so caused the S-03a "State mismatch").
//
// The port is chosen by the system each time (RFC 8252 §7.3: a native app's
// loopback redirect may use any port). A fixed port broke sign-in on Windows
// once Hyper-V/WSL reserved a port range that contained it (spike S-03
// finding); the Supabase redirect list allows any port on 127.0.0.1
// (`http://127.0.0.1:*/callback`, AuthConfig.desktopRedirectPattern).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_config.dart';

/// Opens the browser at an authorize URL; returns whether it opened.
typedef LaunchBrowser = Future<bool> Function(Uri url);

Future<bool> _launch(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

class DesktopLoopback {
  DesktopLoopback._(this._server) : redirect = AuthConfig.desktopRedirectFor(_server.port);

  final HttpServer _server;

  /// One sign-in at a time: a second one would race for the browser tab.
  static bool _busy = false;

  /// Binds a free loopback port picked by the system.
  static Future<DesktopLoopback> open() async {
    if (_busy) {
      throw const AuthFailure(AuthFailureKind.other,
          'Another sign-in is already waiting. Finish or close it first.');
    }
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } on SocketException {
      throw const AuthFailure(AuthFailureKind.other,
          'Could not start sign-in on this computer. Try again.');
    }
    _busy = true;
    return DesktopLoopback._(server);
  }

  /// The redirect for this sign-in: the port the system gave.
  final String redirect;

  /// Opens [authorizeUrl] and waits for the browser to come back with the
  /// code. The loopback is closed afterwards, whatever happens.
  Future<String> capture({
    required Uri authorizeUrl,
    Duration timeout = AuthConfig.oauthTimeout,
    LaunchBrowser launch = _launch,
  }) async {
    final completer = Completer<String>();

    final sub = _server.listen((req) async {
      if (req.uri.path != '/callback') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final code = req.uri.queryParameters['code'];
      final error = req.uri.queryParameters['error_description'] ??
          req.uri.queryParameters['error'];
      req.response.headers.contentType = ContentType.html;
      if (error != null) {
        req.response.write(_page('Sign-in failed: $error. You can close this tab.'));
        await req.response.close();
        if (!completer.isCompleted) {
          completer.completeError(AuthFailure(AuthFailureKind.other, 'Sign-in failed: $error'));
        }
        return;
      }
      if (code == null) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.write(_page('Missing code. You can close this tab.'));
        await req.response.close();
        return;
      }
      req.response.write(_page('Signed in. You can close this tab and return to LifeFlow.'));
      await req.response.close();
      if (!completer.isCompleted) completer.complete(code);
    });

    try {
      if (!await launch(authorizeUrl)) {
        throw const AuthFailure(AuthFailureKind.other, 'Could not open the browser.');
      }
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
      await close();
    }
  }

  /// Frees the port (also when the authorize URL could not be made).
  Future<void> close() async {
    if (!_busy) return;
    _busy = false;
    await _server.close(force: true);
  }

  /// Every dynamic string is HTML-escaped: `error` comes from the URL and must
  /// not be able to inject markup into this page.
  static String _page(String message) =>
      '<!doctype html><html><head><meta charset="utf-8"><title>LifeFlow</title>'
      '</head><body style="font-family:sans-serif;padding:2rem">'
      '<h3>LifeFlow</h3><p>${const HtmlEscape().convert(message)}</p></body></html>';
}
