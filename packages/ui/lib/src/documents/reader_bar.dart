// P05b T4 (ADR-0078; D5, D7): the reading-aloud controls under a document.
import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n.dart';
import 'read_aloud.dart';

/// "1.25" for 1.25, "1" for 1.0.
String speedText(double s) => s == s.roundToDouble() ? s.toStringAsFixed(0) : '$s';

class ReaderBar extends StatelessWidget {
  const ReaderBar({super.key, required this.reader, required this.onClose});
  final ReadAloud reader;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = reader;
    final playing = r.state == ReadState.playing;
    final note = !r.loaded
        ? l.ttsLoading
        : r.voices.isEmpty
            ? l.ttsNoVoices
            : r.sentences.isEmpty
                ? l.ttsNothingToRead
                : r.failed
                    ? l.ttsCouldNotRead
                    : null;
    final lacks = r.lacksVoice && r.voices.isNotEmpty
        ? '${l.ttsNoVoiceFor(l.ttsLanguage(r.language))} '
            '${defaultTargetPlatform == TargetPlatform.windows ? l.ttsAddVoiceWindows : l.ttsAddVoiceAndroid}'
        : null;
    final canRead = r.voice != null && r.sentences.isNotEmpty;
    return Material(
      key: const Key('doc-reader'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (lacks != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(lacks, key: const Key('tts-no-voice'), style: theme.textTheme.bodySmall),
            ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(note, key: const Key('tts-note'), style: theme.textTheme.bodySmall),
            ),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            IconButton(
                key: const Key('tts-previous'),
                tooltip: l.ttsPrevious,
                icon: const Icon(Icons.skip_previous),
                onPressed: canRead && r.index > 0 ? r.previous : null),
            IconButton(
                key: const Key('tts-play'),
                tooltip: playing ? l.ttsPause : l.ttsPlay,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: !canRead ? null : (playing ? r.pause : r.play)),
            IconButton(
                key: const Key('tts-next'),
                tooltip: l.ttsNext,
                icon: const Icon(Icons.skip_next),
                onPressed: canRead && r.index + 1 < r.sentences.length ? r.next : null),
            if (r.sentences.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(l.ttsSentenceOf(r.index + 1, r.sentences.length), key: const Key('tts-position')),
              ),
            PopupMenuButton<double>(
              key: const Key('tts-speed'),
              tooltip: l.ttsSpeed,
              initialValue: r.speed,
              onSelected: r.setSpeed,
              itemBuilder: (_) => [
                for (final s in readingSpeeds)
                  PopupMenuItem(value: s, key: ValueKey('tts-speed-$s'), child: Text(l.ttsSpeedValue(speedText(s)))),
              ],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l.ttsSpeedValue(speedText(r.speed)), key: const Key('tts-speed-value')),
              ),
            ),
            if (r.voices.isNotEmpty)
              PopupMenuButton<TtsVoice>(
                key: const Key('tts-voice'),
                tooltip: l.ttsVoice,
                initialValue: r.voice,
                onSelected: r.setVoice,
                itemBuilder: (_) => [
                  for (final v in r.voices)
                    PopupMenuItem(
                        value: v, key: ValueKey('tts-voice-${v.name}'), child: Text(l.ttsVoiceItem(v.name, v.locale))),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.record_voice_over_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text(r.voice?.name ?? l.ttsVoice, key: const Key('tts-voice-name')),
                  ]),
                ),
              ),
            IconButton(key: const Key('tts-close'), tooltip: l.ttsClose, icon: const Icon(Icons.close), onPressed: onClose),
          ]),
        ]),
      ),
    );
  }
}
