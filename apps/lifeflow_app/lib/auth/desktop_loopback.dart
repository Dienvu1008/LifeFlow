// Windows OAuth redirect capture on a fixed loopback port (spike S-03a).
// Binds 127.0.0.1 only, serves exactly the /callback redirect, returns the
// authorization code. The SDK owns PKCE + state, so state is NOT validated
// here (doing so caused the S-03a "State mismatch").
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_config.dart';

class DesktopLoopback {
  static Future<String> capture({
    required Uri authorizeUrl,
    Duration timeout = AuthConfig.oauthTimeout,
  }) async {
    final HttpServer server;
    try {
      server = await HttpServer.bind(
          InternetAddress.loopbackIPv4, AuthConfig.desktopPort);
    } on SocketException {
      throw const AuthFailure(AuthFailureKind.other,
          'Another sign-in is already waiting. Finish or close it first.');
    }
    final completer = Completer<String>();

    final sub = server.listen((req) async {
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
      if (!await launchUrl(authorizeUrl, mode: LaunchMode.externalApplication)) {
        throw const AuthFailure(AuthFailureKind.other, 'Could not open the browser.');
      }
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  /// Every dynamic string is HTML-escaped: `error` comes from the URL and must
  /// not be able to inject markup into this page.
  static String _page(String message) =>
      '<!doctype html><html><head><meta charset="utf-8"><title>LifeFlow</title>'
      '</head><body style="font-family:sans-serif;padding:2rem">'
      '<h3>LifeFlow</h3><p>${const HtmlEscape().convert(message)}</p></body></html>';
}
