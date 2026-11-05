// THROWAWAY spike S-01. Minimal UI to exercise Drift CRUD + a transaction.
import 'package:flutter/material.dart';

import 'database.dart';

void main() => runApp(const SpikeApp());

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
  final _db = SpikeDb();
  String _log = '';
  int _seq = 0;

  void _append(String m) => setState(() => _log = '$m\n$_log');

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _append('OK: $label');
    } catch (e) {
      _append('ERR: $label -> $e');
    }
  }

  Future<void> _createTx() async {
    final id = 'deck-${_seq++}';
    await _run('create deck + 2 cards in one transaction',
        () => _db.createDeckWithCards(id, 'Deck $id'));
    await _refresh();
  }

  Future<void> _refresh() async {
    final decks = await _db.allDecks();
    final count = await _db.countCards();
    _append('read: ${decks.length} decks, $count cards total');
  }

  Future<void> _failingTx() async {
    const id = 'tx-fail';
    await _run('transaction rollback check', () async {
      try {
        await _db.transaction(() async {
          await _db.into(_db.decks).insert(
              DecksCompanion.insert(id: id, title: 'should rollback'));
          // Duplicate primary key -> throws, rolls back the whole transaction.
          await _db.into(_db.decks).insert(
              DecksCompanion.insert(id: id, title: 'dup'));
        });
      } catch (_) {
        // expected
      }
      final decks = await _db.allDecks();
      final leaked = decks.any((d) => d.id == id);
      _append(leaked
          ? 'ROLLBACK FAILED: $id leaked'
          : 'rollback OK: $id not persisted');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S-01 Drift spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 8, children: [
              ElevatedButton(onPressed: _createTx, child: const Text('Create (tx)')),
              ElevatedButton(onPressed: _refresh, child: const Text('Read')),
              ElevatedButton(onPressed: _failingTx, child: const Text('Rollback test')),
            ]),
            const SizedBox(height: 12),
            const Text('Log (newest first):'),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_log, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
