// Windows sign-in redirect (spike S-03a; port fix after spike S-03): the
// loopback takes a port the system picks, so a range Windows reserves can
// no longer block sign-in; the redirect matches the pattern allowed in the
// Supabase project; the code comes back, errors are shown escaped, and the
// port is always freed.
import 'dart:io';

import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeflow_app/auth/auth_config.dart';
import 'package:lifeflow_app/auth/desktop_loopback.dart';

/// Supabase's redirect wildcard: `*` is any run of characters other than
/// the separators `.` and `/`.
bool matchesPattern(String url, String pattern) => RegExp(
        '^${pattern.split('*').map(RegExp.escape).join(r'[^./]*')}\$')
    .hasMatch(url);

/// The browser: follows the authorize URL by calling the redirect.
LaunchBrowser browserReturning(String redirect, String query, {List<String>? pages}) => (url) async {
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse('$redirect?$query'));
        final res = await req.close();
        pages?.add(await res.transform(const SystemEncoding().decoder).join());
        // A real browser returns from launch long before the redirect; this
        // one returns after it, so the code must already be listening.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      } finally {
        client.close(force: true);
      }
      return true;
    };

Future<bool> portFree(int port) async {
  try {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await s.close();
    return true;
  } on SocketException {
    return false;
  }
}

int portOf(String redirect) => Uri.parse(redirect).port;

void main() {
  test('the system picks the port; the redirect matches the allowed pattern', () async {
    final a = await DesktopLoopback.open();
    final port = portOf(a.redirect);
    await a.close();
    expect(port, greaterThan(0));
    expect(a.redirect, 'http://127.0.0.1:$port/callback');
    expect(matchesPattern(a.redirect, AuthConfig.desktopRedirectPattern), isTrue);
    expect(matchesPattern('http://127.0.0.1:1234/other', AuthConfig.desktopRedirectPattern), isFalse);
    expect(matchesPattern('http://evil.example:1234/callback', AuthConfig.desktopRedirectPattern), isFalse);
  });

  test('a taken port does not block sign-in', () async {
    // Hold the port a first sign-in used, as a reserved range would: the
    // next sign-in still opens, on another port.
    final first = await DesktopLoopback.open();
    final used = portOf(first.redirect);
    await first.close();
    final held = await ServerSocket.bind(InternetAddress.loopbackIPv4, used);
    addTearDown(held.close);
    final loopback = await DesktopLoopback.open();
    expect(portOf(loopback.redirect), isNot(used));
    await loopback.close();
  });

  test('the code comes back and the port is freed', () async {
    final loopback = await DesktopLoopback.open();
    final redirect = loopback.redirect;
    final pages = <String>[];
    final code = await loopback.capture(
      authorizeUrl: Uri.parse('https://auth.example/authorize'),
      launch: browserReturning(redirect, 'code=abc123', pages: pages),
    );
    expect(code, 'abc123');
    expect(pages.single, contains('Signed in.'));
    expect(await portFree(portOf(redirect)), isTrue);
  });

  test('an error from the provider fails the sign-in, escaped on the page', () async {
    final loopback = await DesktopLoopback.open();
    final redirect = loopback.redirect;
    final pages = <String>[];
    await expectLater(
      loopback.capture(
        authorizeUrl: Uri.parse('https://auth.example/authorize'),
        launch: browserReturning(redirect, 'error=%3Cscript%3Ex%3C%2Fscript%3E', pages: pages),
      ),
      throwsA(isA<AuthFailure>().having((f) => f.message, 'message', contains('<script>'))),
    );
    expect(pages.single, isNot(contains('<script>')));
    expect(pages.single, contains('&lt;script&gt;'));
    expect(await portFree(portOf(redirect)), isTrue);
  });

  test('one sign-in at a time; a browser that does not open frees the port', () async {
    final first = await DesktopLoopback.open();
    await expectLater(DesktopLoopback.open(), throwsA(isA<AuthFailure>()));
    final redirect = first.redirect;
    await expectLater(
      first.capture(authorizeUrl: Uri.parse('https://auth.example/authorize'), launch: (_) async => false),
      throwsA(isA<AuthFailure>().having((f) => f.message, 'message', contains('browser'))),
    );
    expect(await portFree(portOf(redirect)), isTrue);
    final again = await DesktopLoopback.open();
    await again.close();
  });

  test('other paths get 404 and do not end the sign-in', () async {
    final loopback = await DesktopLoopback.open();
    final redirect = loopback.redirect;
    final code = await loopback.capture(
      authorizeUrl: Uri.parse('https://auth.example/authorize'),
      launch: (url) async {
        final client = HttpClient();
        final other = await (await client.getUrl(Uri.parse(redirect.replaceFirst('/callback', '/favicon.ico')))).close();
        expect(other.statusCode, HttpStatus.notFound);
        await other.drain<void>();
        client.close(force: true);
        return browserReturning(redirect, 'code=later')(url);
      },
    );
    expect(code, 'later');
  });
}
