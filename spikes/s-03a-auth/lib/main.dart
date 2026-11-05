// THROWAWAY spike S-03a. Minimal UI to exercise the success criteria.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'config.dart';

/// Stores the gotrue session in platform secure storage (SR-02/SR-07), so it
/// survives restart and is not in plain files.
class SecureGotrueStorage extends LocalStorage {
  final _s = const FlutterSecureStorage();
  static const _key = 'lifeflow_spike_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async => _s.read(key: _key);

  @override
  Future<bool> hasAccessToken() async => _s.containsKey(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) async =>
      _s.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() async => _s.delete(key: _key);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SpikeConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }
  await Supabase.initialize(
    url: SpikeConfig.supabaseUrl,
    // The "anon"/publishable client key. Named define kept as SUPABASE_ANON_KEY
    // for the runbook; passed as the publishable key (new API name).
    anonKey: SpikeConfig.supabaseAnonKey, // ignore: deprecated_member_use
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureGotrueStorage(),
      // PKCE is the default auth flow type in supabase_flutter v2.
      authFlowType: AuthFlowType.pkce,
    ),
  );
  runApp(const SpikeApp());
}

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _simulateOffline = false;
  String _log = '';

  void _append(String m) => setState(() => _log = '$m\n$_log');

  AuthStatus get _status => _auth.statusOffline(online: !_simulateOffline);

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _append('OK: $label');
    } catch (e) {
      _append('ERR: $label -> $e');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = _auth.session;
    return Scaffold(
      appBar: AppBar(title: const Text('S-03a auth spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Platform: ${kIsWeb ? "web" : defaultTargetPlatform.name}'),
            Text('Status: $_status'),
            Text('User: ${s?.user.email ?? s?.user.id ?? "(none)"}'),
            Text('Token expires at (epoch): ${s?.expiresAt ?? "-"}'),
            SwitchListTile(
              title: const Text('Simulate offline (status derived, no network)'),
              value: _simulateOffline,
              onChanged: (v) => setState(() => _simulateOffline = v),
            ),
            const Divider(),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'email')),
            TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'password')),
            Wrap(spacing: 8, children: [
              ElevatedButton(
                onPressed: () => _run('email sign-in',
                    () => _auth.signInWithEmail(_email.text.trim(), _password.text)),
                child: const Text('Sign in (email)'),
              ),
              ElevatedButton(
                onPressed: () => _run('email sign-up',
                    () => _auth.signUpWithEmail(_email.text.trim(), _password.text)),
                child: const Text('Sign up (email)'),
              ),
              ElevatedButton(
                onPressed: () => _run('GitHub sign-in', _auth.signInWithGitHub),
                child: const Text('Sign in (GitHub)'),
              ),
              OutlinedButton(
                onPressed: () => _run('sign-out', _auth.signOut),
                child: const Text('Sign out'),
              ),
            ]),
            const Divider(),
            const Text('Log (newest first):'),
            Text(_log, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Missing config. Pass --dart-define=SUPABASE_URL=... and '
                '--dart-define=SUPABASE_ANON_KEY=... (see runbook).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
