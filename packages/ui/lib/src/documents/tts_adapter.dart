// P05b T4 (ADR-0078; S-12): the only place that knows flutter_tts. It is the
// app's TtsPort: the device's own voices, nothing sent anywhere.
//   one at a time  each speak() completes when the voice finished (true) or
//                  was stopped (false); Windows sends no word progress, so
//                  the reader goes sentence by sentence on every platform
//   speed          1 is the voice's own pace: Android takes value × 2 (its
//                  1.0 is normal), Windows value + 0.5 (its SpeakingRate)
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// flutter_tts's rate for a reading [speed] on [platform] (see above).
double platformRateOf(double speed, TargetPlatform platform) {
  final s = speed.clamp(minReadingSpeed, maxReadingSpeed);
  return switch (platform) {
    TargetPlatform.windows => s - 0.5,
    // Android (and iOS, macOS): 0.5 is the normal pace.
    _ => s / 2,
  };
}

class FlutterTtsPort implements TtsPort {
  FlutterTts? _tts;
  Completer<bool>? _done;

  Future<FlutterTts> _engine() async {
    final t = _tts;
    if (t != null) return t;
    final tts = FlutterTts();
    tts.setCompletionHandler(() => _finish(true));
    // A cancel comes after our own stop(), which has finished the sentence
    // already; it may arrive when the next one has started: not ours to end.
    tts.setCancelHandler(() {});
    tts.setErrorHandler((_) => _finish(false));
    await tts.awaitSpeakCompletion(false);
    return _tts = tts;
  }

  void _finish(bool read) {
    final d = _done;
    _done = null;
    if (d != null && !d.isCompleted) d.complete(read);
  }

  @override
  Future<List<TtsVoice>> voices() async {
    try {
      final raw = await (await _engine()).getVoices;
      return [
        for (final v in (raw is List ? raw : const []))
          if (v is Map && v['name'] != null && v['locale'] != null) TtsVoice(name: '${v['name']}', locale: '${v['locale']}'),
      ]..sort((a, b) => a.locale == b.locale ? a.name.compareTo(b.name) : a.locale.compareTo(b.locale));
    } on Object {
      return const []; // no engine on this device
    }
  }

  @override
  Future<bool> speak(String text, {required TtsVoice voice, required double speed}) async {
    final tts = await _engine();
    _finish(false);
    final done = _done = Completer<bool>();
    try {
      await tts.setVoice({'name': voice.name, 'locale': voice.locale});
      await tts.setSpeechRate(platformRateOf(speed, defaultTargetPlatform));
      final r = await tts.speak(text);
      if (r != 1) _finish(false);
    } on Object {
      _finish(false);
    }
    return done.future;
  }

  @override
  Future<void> stop() async {
    final t = _tts;
    _finish(false);
    if (t != null) await t.stop();
  }
}
