// P05b T4 (ADR-0078; p05b-plan.md D5, D7; document-knowledge.md §6): the
// device's voices, behind a port. Nothing leaves the device: the voices are
// the system's (Android's text-to-speech engine, Windows' voices).

/// What is read: the domain's sentence model (pure).
export 'package:domain/domain.dart' show ReadingSentence, maxReadingSentenceLength, readingLanguageOf, readingOf, sentencesOf;

/// A voice of this device.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});
  final String name;

  /// As the system gives it: `vi-VN`, `en_US`, …
  final String locale;

  /// The language part, lower case: `vi`, `en`.
  String get language => locale.split(RegExp('[-_]')).first.toLowerCase();

  @override
  bool operator ==(Object o) => o is TtsVoice && o.name == name && o.locale == locale;
  @override
  int get hashCode => Object.hash(name, locale);
}

/// The slowest and fastest reading speeds (1 is the voice's own).
const minReadingSpeed = 0.5, maxReadingSpeed = 2.0;

/// The speeds offered.
const readingSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

abstract interface class TtsPort {
  /// The voices of this device (empty when it has none, or no engine).
  Future<List<TtsVoice>> voices();

  /// Reads [text] aloud with [voice] at [speed] (clamped to the bounds).
  /// Completes when it was read to the end (true), or stopped (false).
  Future<bool> speak(String text, {required TtsVoice voice, required double speed});

  /// Stops at once; a [speak] in progress completes with false.
  Future<void> stop();
}
