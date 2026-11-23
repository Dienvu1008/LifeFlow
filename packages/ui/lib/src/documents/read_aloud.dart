// P05b T4 (ADR-0078; p05b-plan.md D5, D6, D7): reading a document aloud.
//   sentences  from the text shown (domain readingOf), one at a time: the
//              next starts when the voice finished the last
//   controls   read, pause (the voice stops; reading again starts that
//              sentence over), stop (back to the start), previous and next
//              sentence; speed 0.5×–2×
//   voice      the one chosen on this device for the document's language,
//              else the first of that language; none: the reader says which
//              language the device lacks (D5) and any voice can be picked
//   remembered speed and the voice per language, on this device (D7)
import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tts_adapter.dart';

/// The device's voices (flutter_tts unless overridden: tests).
final ttsPortProvider = Provider<TtsPort>((ref) {
  final port = FlutterTtsPort();
  ref.onDispose(port.stop);
  return port;
});

enum ReadState { stopped, playing, paused }

class ReadAloud extends ChangeNotifier {
  ReadAloud(this._tts, this._settings);
  final TtsPort _tts;
  final SettingsService _settings;

  List<ReadingSentence> sentences = const [];

  /// The sentence being read (or to read next), 0-based.
  int index = 0;
  ReadState state = ReadState.stopped;
  double speed = 1.0;
  List<TtsVoice> voices = const [];
  TtsVoice? voice;

  /// `vi` or `en`: the document's language, as guessed.
  String language = 'en';

  /// The voice could not read the last sentence.
  bool failed = false;
  bool loaded = false;
  var _run = 0;
  var _disposed = false;

  /// No voice of the document's language on this device.
  bool get lacksVoice => loaded && !voices.any((v) => v.language == language);
  ReadingSentence? get current => index < sentences.length ? sentences[index] : null;

  Future<void> load(DocumentBody body) async {
    sentences = readingOf(body);
    language = readingLanguageOf(body);
    voices = await _tts.voices();
    speed = await _settings.readingSpeed();
    final chosen = await _settings.readingVoice(language);
    voice = voices.where((v) => v.name == chosen).firstOrNull ??
        voices.where((v) => v.language == language).firstOrNull;
    loaded = true;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Reads from the current sentence to the end.
  Future<void> play() async {
    final v = voice;
    if (v == null || sentences.isEmpty) return;
    final run = ++_run;
    if (index >= sentences.length) index = 0;
    state = ReadState.playing;
    failed = false;
    _changed();
    while (index < sentences.length) {
      final read = await _tts.speak(sentences[index].text, voice: v, speed: speed);
      if (run != _run || _disposed) return; // paused, stopped, moved, changed
      if (!read) {
        state = ReadState.paused;
        failed = true;
        _changed();
        return;
      }
      if (index + 1 >= sentences.length) break;
      index++;
      _changed();
    }
    state = ReadState.stopped;
    index = 0;
    _changed();
  }

  Future<void> pause() async {
    if (state != ReadState.playing) return;
    _run++;
    state = ReadState.paused;
    _changed();
    await _tts.stop();
  }

  Future<void> stop() async {
    _run++;
    final was = state;
    state = ReadState.stopped;
    index = 0;
    _changed();
    if (was == ReadState.playing) await _tts.stop();
  }

  Future<void> _restartIfPlaying() async {
    if (state != ReadState.playing) return _changed();
    _run++;
    await _tts.stop();
    await play();
  }

  Future<void> next() async {
    if (index + 1 >= sentences.length) return;
    index++;
    await _restartIfPlaying();
  }

  Future<void> previous() async {
    if (index == 0) return;
    index--;
    await _restartIfPlaying();
  }

  Future<void> setSpeed(double s) async {
    speed = s.clamp(minReadingSpeed, maxReadingSpeed);
    await _settings.setReadingSpeed(speed);
    await _restartIfPlaying();
  }

  Future<void> setVoice(TtsVoice v) async {
    voice = v;
    await _settings.setReadingVoice(language, v.name);
    await _restartIfPlaying();
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    if (state == ReadState.playing) _tts.stop();
    super.dispose();
  }
}
