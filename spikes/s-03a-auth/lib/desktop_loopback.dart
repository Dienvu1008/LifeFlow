// THROWAWAY spike S-03a. Windows/desktop OAuth via a fixed-port loopback server.
//
// Flow: bind 127.0.0.1:53682, open the GitHub authorize URL (through Supabase)
// with our PKCE challenge + state, wait for the browser redirect to
// /callback?code=...&state=..., validate state (CSRF), return the code. The
// code is then exchanged by Supabase (exchangeCodeForSession) in auth_service.
import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

class LoopbackResult {
  LoopbackResult(this.code);
  final String code;
}

class DesktopLoopback {
  /// Runs the loopback capture. [authorizeUrl] must already include our
  /// redirect_uri (desktopRedirect), code_challenge (S256), state and scope.
  /// Times out after [timeout]. Throws on state mismatch or timeout.
  static Future<LoopbackResult> capture({
    required Uri authorizeUrl,
    required String expectedState,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      SpikeConfig.desktopPort,
    );
    final completer = Completer<LoopbackResult>();

    // Serve exactly one meaningful request (the redirect); ignore favicon etc.
    final sub = server.listen((HttpRequest req) async {
      final uri = req.uri;
      if (uri.path != '/callback') {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];

      req.response.headers.contentType = ContentType.html;
      if (error != null) {
        req.response.write(_html('Sign-in failed: $error. You can close this tab.'));
        await req.response.close();
        if (!completer.isCompleted) {
          completer.completeError(StateError('OAuth error: $error'));
        }
        return;
      }
      if (state != expectedState) {
        req.response.statusCode = 400;
        req.response.write(_html('State mismatch. You can close this tab.'));
        await req.response.close();
        if (!completer.isCompleted) {
          completer.completeError(StateError('State mismatch (possible CSRF)'));
        }
        return;
      }
      if (code == null) {
        req.response.statusCode = 400;
        req.response.write(_html('Missing code. You can close this tab.'));
        await req.response.close();
        return;
      }
      req.response.write(_html('Signed in. You can close this tab and return to LifeFlow.'));
      await req.response.close();
      if (!completer.isCompleted) completer.complete(LoopbackResult(code));
    });

    // Open the system browser for the authorization step.
    if (!await launchUrl(authorizeUrl, mode: LaunchMode.externalApplication)) {
      await sub.cancel();
      await server.close(force: true);
      throw StateError('Could not open the browser for authorization');
    }

    try {
      return await completer.future.timeout(timeout);
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  static String _html(String message) =>
      '<!doctype html><html><body style="font-family:sans-serif;padding:2rem">'
      '<h3>LifeFlow spike S-03a</h3><p>$message</p></body></html>';
}
