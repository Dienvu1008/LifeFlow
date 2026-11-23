// P05b T4: the device's voices, faked. A sentence is "read" when the test
// calls [FakeTts.finish]; calls are recorded (`tts.speak:<voice>:<speed>:<text>`,
// `tts.stop`).
import 'dart:async';

import 'package:application/application.dart';

const an = TtsVoice(name: 'Microsoft An', locale: 'vi-VN');
const zira = TtsVoice(name: 'Microsoft Zira', locale: 'en-US');
const david = TtsVoice(name: 'Microsoft David', locale: 'en-US');

class FakeTts implements TtsPort {
  FakeTts(this.calls);
  final List<String> calls;
  List<TtsVoice> list = [an, david, zira];
  Completer<bool>? _pending;

  /// What is being read now, or null.
  String? speaking;

  @override
  Future<List<TtsVoice>> voices() async => [...list];

  @override
  Future<bool> speak(String text, {required TtsVoice voice, required double speed}) {
    calls.add('tts.speak:${voice.name}:$speed:$text');
    _pending?.complete(false);
    speaking = text;
    return (_pending = Completer<bool>()).future;
  }

  @override
  Future<void> stop() async {
    calls.add('tts.stop');
    finish(false);
  }

  /// The voice finished the sentence ([read]), or failed (false).
  void finish([bool read = true]) {
    final p = _pending;
    _pending = null;
    speaking = null;
    if (p != null && !p.isCompleted) p.complete(read);
  }
}
