// Dogfooding T2 (ADR-0051): one line of text that, when it is wider than
// its space, slides sideways inside that space so all of it can be read: a
// pause, a slide to the end, a pause, then it rests at the start, cut with
// an ellipsis. It plays once each time the text (or its space) changes, so
// nothing on screen keeps moving for long (WCAG 2.2.2). When it fits it is
// plain text; with animations turned off it only gets the ellipsis.
import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.speed = 30,
    this.pause = const Duration(milliseconds: 1200),
  });

  final String text;
  final TextStyle? style;

  /// Logical pixels per second while sliding.
  final double speed;

  /// How long it rests at each end.
  final Duration pause;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this);
  (String, double)? _played;
  double _overflow = 0;
  Duration _slide = Duration.zero;

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  /// Plays once for this text and overflow; after the frame, as the
  /// controller must not notify during layout.
  void _schedule(double overflow) {
    final what = (widget.text, overflow);
    if (what == _played) return;
    _played = what;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _played != what) return;
      _overflow = overflow;
      if (overflow <= 0) {
        _run.reset();
        return;
      }
      _slide = Duration(milliseconds: (overflow / widget.speed * 1000).round());
      _run
        ..duration = widget.pause * 2 + _slide
        ..forward(from: 0);
    });
  }

  /// How far the text has slid at this point of the run.
  double _offset() {
    final total = _run.duration;
    if (total == null || _slide == Duration.zero) return 0;
    final t = _run.value * total.inMicroseconds - widget.pause.inMicroseconds;
    return Curves.easeInOut.transform((t / _slide.inMicroseconds).clamp(0.0, 1.0)) * _overflow;
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final direction = Directionality.of(context);
    final resting = Text(widget.text, style: widget.style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis);
    return LayoutBuilder(builder: (context, box) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        textDirection: direction,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      final height = painter.height;
      painter.dispose();
      final overflow = box.hasBoundedWidth && width > box.maxWidth ? width - box.maxWidth : 0.0;
      _schedule(still ? 0 : overflow);
      if (overflow == 0 || still) return resting;
      final sign = direction == TextDirection.rtl ? 1.0 : -1.0;
      return SizedBox(
        width: box.maxWidth,
        height: height,
        child: AnimatedBuilder(
          animation: _run,
          builder: (context, child) => _run.isAnimating
              ? ClipRect(
                  key: const Key('marquee'),
                  child: Transform.translate(offset: Offset(sign * _offset(), 0), child: child),
                )
              : resting,
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            minWidth: 0,
            maxWidth: double.infinity,
            child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
          ),
        ),
      );
    });
  }
}
