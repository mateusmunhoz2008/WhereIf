import 'dart:async';
import 'dart:math' as math;

import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _ink = Color(0xFF151419);
const _paper = Color(0xFFFFFEFC);
const _assets = ['campus', 'agenda', 'hours'];

Color _paperColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface
        : _paper;

Color _inkColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurface
        : _ink;

List<Color> _pagePalette(BuildContext context, int index) {
  final colors = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final accents = [colors.primary, colors.secondary, colors.error];
  final backdrop = dark ? colors.surface : _paper;
  return List.generate(
      3,
      (offset) => Color.lerp(
          backdrop, accents[(index + offset) % 3], dark ? .38 : .34)!);
}

/// Only the final arrow saves completion. Skipping and leaving early do not.
class CampusOnboarding extends StatefulWidget {
  const CampusOnboarding({super.key, required this.onFinished});
  final Future<void> Function() onFinished;

  @override
  State<CampusOnboarding> createState() => _CampusOnboardingState();
}

class _CampusOnboardingState extends State<CampusOnboarding>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
    reverseDuration: const Duration(milliseconds: 280),
  );
  final _warmed = <int>{};
  int _index = 0;
  bool _finishing = false;
  bool _changingStep = false;
  bool _reducedMotion = false;
  bool _initialTextReady = false;
  bool _entryBackdropRevealed = false;
  int _decodeWidth = 720;

  @override
  void initState() {
    super.initState();
    _entrance.addListener(_updateEntranceStages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_reducedMotion) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    });
  }

  void _updateEntranceStages() {
    if (!mounted) return;
    final revealText = !_initialTextReady && _entrance.value >= .5;
    final revealBackdrop = !_entryBackdropRevealed && _entrance.value >= .75;
    if (!revealText && !revealBackdrop) return;
    setState(() {
      if (revealText) _initialTextReady = true;
      if (revealBackdrop) _entryBackdropRevealed = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) _initialTextReady = true;
    _decodeWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .clamp(720, 1280)
        .round();
    _warmArt();
  }

  void _warmArt() {
    for (final index in {_index, math.min(_index + 1, 2)}) {
      if (!_warmed.add(index)) continue;
      unawaited(precacheImage(_artProvider(index, _decodeWidth), context));
    }
  }

  Future<void> _goTo(int index) async {
    if (!_reducedMotion && !_entrance.isCompleted) return;
    if (_finishing || _changingStep || index == _index) return;
    if (_pages.position.isScrollingNotifier.value) return;
    if (_reducedMotion) {
      _pages.jumpToPage(index);
      return;
    }
    setState(() => _changingStep = true);
    await _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
    if (mounted) setState(() => _changingStep = false);
  }

  Future<void> _next() async {
    if (!_reducedMotion && !_entrance.isCompleted) return;
    if (_finishing || _changingStep) return;
    if (_pages.position.isScrollingNotifier.value) return;
    if (_index < 2) {
      _goTo(_index + 1);
      return;
    }
    setState(() => _finishing = true);
    if (!_reducedMotion) await _entrance.reverse();
    if (!mounted) return;
    await widget.onFinished();
  }

  @override
  void dispose() {
    _pages.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = _paperColor(context);
    final ink = _inkColor(context);
    final splashColor = Theme.of(context).colorScheme.tertiary;
    final backdropEntrance = _entryBackdropRevealed
        ? const AlwaysStoppedAnimation<double>(1)
        : _entrance.drive(CurveTween(
            curve: const Interval(0, .75, curve: Curves.easeInOutCubic)));
    final entrance = _reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : _entrance.drive(CurveTween(
            curve: const Interval(0, .55, curve: Curves.easeInOutCubic)));
    final controlsEntrance = _reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : _entrance.drive(CurveTween(
            curve: const Interval(.65, 1, curve: Curves.easeOutCubic)));
    return AnimatedBuilder(
      animation: backdropEntrance,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor:
              Color.lerp(splashColor, paper, backdropEntrance.value),
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
        ),
        child: child!,
      ),
      child: PopScope(
        canPop: !_finishing,
        child: Scaffold(
          backgroundColor: paper,
          body: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: _reducedMotion ? 0 : 500),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _pagePalette(context, _index),
                  stops: const [0, .48, 1],
                )),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: FadeTransition(
                      opacity: entrance,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .025),
                          end: Offset.zero,
                        ).animate(entrance),
                        child: Stack(children: [
                          const Positioned.fill(child: _GradientBloom()),
                          Positioned.fill(
                              child: IgnorePointer(
                            ignoring: _finishing,
                            child: PageView.builder(
                              key: const ValueKey('onboarding-pages'),
                              controller: _pages,
                              itemCount: 3,
                              physics: const NeverScrollableScrollPhysics(),
                              onPageChanged: (index) {
                                setState(() => _index = index);
                                _warmArt();
                              },
                              itemBuilder: (context, index) => _OnboardingScene(
                                index: index,
                                active: index == _index,
                                textActive: index == _index &&
                                    _initialTextReady &&
                                    !_changingStep &&
                                    !_finishing,
                                decodeWidth: _decodeWidth,
                                reducedMotion: _reducedMotion,
                                pages: _pages,
                                initialEntrance: index == 0 ? _entrance : null,
                              ),
                            ),
                          )),
                          FadeTransition(
                              key: const ValueKey(
                                  'onboarding-controls-entrance'),
                              opacity: controlsEntrance,
                              child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, .04),
                                    end: Offset.zero,
                                  ).animate(controlsEntrance),
                                  child: SafeArea(
                                      child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        26, 8, 26, 18),
                                    child: Column(children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text('WhereIF',
                                                textScaler:
                                                    TextScaler.noScaling,
                                                style: TextStyle(
                                                  fontFamily: 'ArchivoBlack',
                                                  fontSize: 21,
                                                  color: ink,
                                                  letterSpacing: -.8,
                                                ))),
                                        AnimatedSwitcher(
                                          duration: Duration(
                                              milliseconds:
                                                  _reducedMotion ? 0 : 180),
                                          child: _index < 2
                                              ? TextButton(
                                                  key: const ValueKey(
                                                      'onboarding-skip'),
                                                  onPressed: _finishing
                                                      ? null
                                                      : () => _goTo(2),
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: ink,
                                                    textStyle: const TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  child:
                                                      Text(l10n.onboardingSkip),
                                                )
                                              : const SizedBox(
                                                  height: 48, width: 48),
                                        ),
                                      ]),
                                      const Spacer(),
                                      Row(children: [
                                        _ProgressDots(
                                          index: _index,
                                          label: l10n.onboardingProgress,
                                          reducedMotion: _reducedMotion,
                                        ),
                                        Expanded(
                                            child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: AnimatedSwitcher(
                                                  duration: Duration(
                                                      milliseconds:
                                                          _reducedMotion
                                                              ? 0
                                                              : 180),
                                                  child: Text(
                                                    _index == 2
                                                        ? l10n.onboardingFinish
                                                        : l10n.onboardingNext,
                                                    key: ValueKey(_index == 2),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: ink),
                                                  ),
                                                ))),
                                        const SizedBox(width: 14),
                                        _ArrowButton(
                                          label: _index == 2
                                              ? l10n.onboardingFinish
                                              : l10n.onboardingNext,
                                          onPressed: _finishing ? null : _next,
                                          reducedMotion: _reducedMotion,
                                        ),
                                      ]),
                                    ]),
                                  )))),
                          if (_finishing)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: FadeTransition(
                                  opacity: Tween<double>(begin: 1, end: 0)
                                      .animate(entrance),
                                  child: ColoredBox(color: paper),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    key: const ValueKey('onboarding-splash-bridge'),
                    opacity: ReverseAnimation(backdropEntrance),
                    child: ColoredBox(
                      key: const ValueKey('onboarding-splash-color'),
                      color: splashColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ImageProvider _artProvider(int index, int width) => ResizeImage(
      AssetImage('assets/onboarding/${_assets[index]}.png'),
      width: width,
    );

class _OnboardingScene extends StatefulWidget {
  const _OnboardingScene(
      {required this.index,
      required this.active,
      required this.textActive,
      required this.decodeWidth,
      required this.reducedMotion,
      this.initialEntrance,
      required this.pages});
  final int index;
  final bool active;
  final bool textActive;
  final int decodeWidth;
  final bool reducedMotion;
  final PageController pages;
  final Animation<double>? initialEntrance;

  @override
  State<_OnboardingScene> createState() => _OnboardingSceneState();
}

class _OnboardingSceneState extends State<_OnboardingScene>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    value: widget.active && !widget.reducedMotion ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _reveal.forward();
  }

  @override
  void didUpdateWidget(covariant _OnboardingScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !widget.reducedMotion) {
      _reveal.forward();
    } else if (!widget.active || widget.reducedMotion) {
      _reveal.value = 1;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Widget _appear(Widget child,
      {double delay = 0, Offset offset = const Offset(0, .06)}) {
    final initial = widget.initialEntrance;
    final animation = widget.reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : initial != null
            ? initial.drive(CurveTween(
                curve: Interval(.12 + delay, .72 + delay * .5,
                    curve: Curves.easeInOutCubic)))
            : _reveal.drive(CurveTween(
                curve: Interval(delay, 1, curve: Curves.easeOutCubic)));
    return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: offset, end: Offset.zero).animate(animation),
          child: child,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = [
      l10n.onboardingMapTitle,
      l10n.onboardingAgendaTitle,
      l10n.onboardingHoursTitle
    ][widget.index];
    final body = [
      l10n.onboardingMapBody,
      l10n.onboardingAgendaBody,
      l10n.onboardingHoursBody
    ][widget.index];
    final insets = MediaQuery.paddingOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final landscape = width > height * 1.15;
      final compact = height < 700;
      final paperTop = landscape ? 0.0 : height * (compact ? .49 : .55);
      final artTop = insets.top + (compact ? 60 : 82);
      final artSize = landscape
          ? math.min(width * .47, height - artTop - 52)
          : math.min(width * 1.04, paperTop - artTop + 78);
      final left = landscape ? width * .49 + 18 : (width > 550 ? 42.0 : 28.0);
      final right = width > 550 ? 42.0 : 28.0;
      return Stack(children: [
        Positioned.fill(
            child: ClipPath(
          clipper: _PaperClipper(top: paperTop, landscape: landscape),
          child: ColoredBox(color: _paperColor(context)),
        )),
        Positioned(
          top: artTop,
          left: landscape ? 0 : (width - artSize) / 2,
          width: artSize,
          height: artSize,
          child: _appear(RepaintBoundary(
              child: Image(
            image: _artProvider(widget.index, widget.decodeWidth),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
          ))),
        ),
        Positioned(
          top: artTop + artSize * (widget.index == 0 ? .13 : .64),
          left: widget.index == 1 ? 24 : null,
          right: widget.index == 1 ? null : (landscape ? width * .52 : 22),
          child: _appear(
              _IllustrationCard(index: widget.index, compact: compact),
              delay: .25,
              offset: const Offset(.12, .08)),
        ),
        Positioned(
          top: landscape ? insets.top + 86 : paperTop + 60,
          bottom: insets.bottom + 100,
          left: left,
          right: right,
          child: _OnboardingCopy(
            index: widget.index,
            title: title,
            body: body,
            disclaimer:
                widget.index == 2 ? l10n.onboardingHoursDisclaimer : null,
            compact: compact,
            landscape: landscape,
            active: widget.textActive,
            reducedMotion: widget.reducedMotion,
          ),
        ),
      ]);
    });
  }
}

class _OnboardingCopy extends StatefulWidget {
  const _OnboardingCopy({
    required this.index,
    required this.title,
    required this.body,
    required this.disclaimer,
    required this.compact,
    required this.landscape,
    required this.active,
    required this.reducedMotion,
  });
  final int index;
  final String title;
  final String body;
  final String? disclaimer;
  final bool compact;
  final bool landscape;
  final bool active;
  final bool reducedMotion;

  @override
  State<_OnboardingCopy> createState() => _OnboardingCopyState();
}

class _OnboardingCopyState extends State<_OnboardingCopy>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    reverseDuration: const Duration(milliseconds: 230),
    value: widget.reducedMotion && widget.active ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active && !widget.reducedMotion) _motion.forward();
  }

  @override
  void didUpdateWidget(covariant _OnboardingCopy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion) {
      _motion.value = widget.active ? 1 : 0;
    } else if (widget.active && !oldWidget.active) {
      _motion.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _motion.reverse();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.index;
    final title = widget.title;
    final body = widget.body;
    final disclaimer = widget.disclaimer;
    final compact = widget.compact;
    final landscape = widget.landscape;
    final colors = Theme.of(context).colorScheme;
    final ink = _inkColor(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final titleSize = landscape ? 26.0 : (compact ? 28.0 : 34.0);
    final bodySize = compact ? 12.5 : 14.0;
    TextStyle titleStyle(double scale) => TextStyle(
          inherit: false,
          fontFamily: 'ArchivoBlack',
          fontSize: titleSize * scale,
          height: 1.08,
          letterSpacing: -.9 * scale,
          color: ink,
        );
    TextStyle bodyStyle(double scale) => TextStyle(
          inherit: false,
          fontFamily: 'Inter',
          fontSize: bodySize * scale,
          height: 1.42,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: colors.onSurface.withValues(alpha: .78),
        );
    TextStyle noteStyle(double scale) => TextStyle(
          inherit: false,
          fontFamily: 'Inter',
          fontSize: 10.5 * scale,
          height: 1.4,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: colors.onSurface.withValues(alpha: .6),
        );

    return LayoutBuilder(builder: (context, constraints) {
      double measure(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          textScaler: scaler,
          locale: Localizations.localeOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final height = painter.height + 1;
        painter.dispose();
        return height;
      }

      double totalHeight(double scale) =>
          measure(title, titleStyle(scale)) +
          12 * scale +
          measure(body, bodyStyle(scale)) +
          (disclaimer == null
              ? 0
              : 9 * scale + measure(disclaimer, noteStyle(scale)));

      var scale = 1.0;
      if (totalHeight(scale) > constraints.maxHeight) {
        var low = .1;
        var high = 1.0;
        for (var iteration = 0; iteration < 10; iteration++) {
          final middle = (low + high) / 2;
          if (totalHeight(middle) <= constraints.maxHeight) {
            low = middle;
          } else {
            high = middle;
          }
        }
        scale = low;
      }
      final content = Column(
        key: ValueKey('onboarding-copy-$index'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
              header: true,
              child: Text(
                title,
                key: ValueKey('onboarding-title-$index'),
                style: titleStyle(scale),
              )),
          SizedBox(height: 12 * scale),
          Text(body, style: bodyStyle(scale)),
          if (disclaimer != null) ...[
            SizedBox(height: 9 * scale),
            Text(disclaimer, style: noteStyle(scale)),
          ],
        ],
      );
      return AnimatedBuilder(
        animation: _motion,
        child: content,
        builder: (context, child) {
          if (widget.reducedMotion) {
            return Align(alignment: Alignment.topLeft, child: child);
          }
          final slide = const Interval(.0, 1, curve: Curves.easeOutCubic)
              .transform(_motion.value);
          final opacity = const Interval(0, .9, curve: Curves.easeOut)
              .transform(_motion.value);
          return Opacity(
            key: ValueKey('onboarding-text-fade-$index'),
            opacity: opacity,
            child: FractionalTranslation(
              key: ValueKey('onboarding-text-slide-$index'),
              translation: Offset(0, -.4 * (1 - slide)),
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          );
        },
      );
    });
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.index, required this.compact});
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final ink = _inkColor(context);
    return Container(
      width: compact ? 160 : 190,
      padding: EdgeInsets.all(compact ? 12 : 15),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? colors.surfaceContainerHigh
            : _paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ink.withValues(alpha: .09)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x201D1236), blurRadius: 22, offset: Offset(0, 8))
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
            fontFamily: 'Inter', color: ink, fontSize: 11, height: 1.35),
        child: switch (index) {
          0 => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.onboardingExample,
                  style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.1,
                      color: Color.lerp(colors.primary, ink, .5))),
              const SizedBox(height: 6),
              Text(l10n.onboardingExampleEvent,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Row(children: [
                Icon(Icons.location_on_rounded, color: colors.error, size: 14),
                const SizedBox(width: 3),
                Flexible(child: Text(l10n.onboardingExampleLocation)),
              ]),
            ]),
          1 => Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: .16),
                    shape: BoxShape.circle),
                child: Icon(Icons.notifications_active_outlined,
                    size: 22, color: Color.lerp(colors.secondary, ink, .3)),
              ),
              const SizedBox(width: 9),
              Flexible(
                  child: Text(l10n.onboardingNotice,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
          _ => Row(children: [
              const Text('12h',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                      fontFamily: 'ArchivoBlack',
                      fontSize: 28,
                      letterSpacing: -1)),
              const SizedBox(width: 12),
              Flexible(
                  child: Text(l10n.onboardingHoursExample,
                      style: const TextStyle(fontSize: 10))),
            ]),
        },
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots(
      {required this.index, required this.label, required this.reducedMotion});
  final int index;
  final String Function(int, int) label;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label(index + 1, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              3,
              (step) => SizedBox(
                    key: ValueKey('onboarding-step-$step'),
                    width: 40,
                    height: 48,
                    child: Center(
                        child: AnimatedContainer(
                      duration: Duration(milliseconds: reducedMotion ? 0 : 260),
                      curve: Curves.easeOutCubic,
                      width: step == index ? 26 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _inkColor(context)
                            .withValues(alpha: step == index ? 1 : .3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )),
                  )),
        ),
      );
}

class _ArrowButton extends StatefulWidget {
  const _ArrowButton(
      {required this.label,
      required this.onPressed,
      required this.reducedMotion});
  final String label;
  final VoidCallback? onPressed;
  final bool reducedMotion;

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.label,
        button: true,
        enabled: widget.onPressed != null,
        child: Tooltip(
            message: widget.label,
            child: GestureDetector(
              key: const ValueKey('onboarding-next'),
              onTapDown: widget.onPressed == null
                  ? null
                  : (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: widget.onPressed,
              child: AnimatedScale(
                scale: _pressed ? .9 : 1,
                duration:
                    Duration(milliseconds: widget.reducedMotion ? 0 : 130),
                curve: Curves.easeOutCubic,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: _inkColor(context),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x18151419),
                            blurRadius: 14,
                            offset: Offset(0, 5))
                      ]),
                  child: SizedBox(
                      width: 58,
                      height: 58,
                      child: Icon(Icons.arrow_forward_rounded,
                          color: _paperColor(context), size: 25)),
                ),
              ),
            )),
      );
}

class _PaperClipper extends CustomClipper<Path> {
  const _PaperClipper({required this.top, required this.landscape});
  final double top;
  final bool landscape;

  @override
  Path getClip(Size size) {
    if (landscape) {
      return Path()
        ..moveTo(size.width * .5, 0)
        ..cubicTo(size.width * .42, size.height * .4, size.width * .58,
            size.height * .55, size.width * .45, size.height * .8)
        ..quadraticBezierTo(
            size.width * .4, size.height * .93, 0, size.height - 85)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0)
        ..close();
    }
    return Path()
      ..moveTo(0, top + 40)
      ..cubicTo(size.width * .2, top + 64, size.width * .23, top - 22,
          size.width * .47, top + 8)
      ..cubicTo(size.width * .74, top + 47, size.width * .86, top - 35,
          size.width, top - 8)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _PaperClipper oldClipper) =>
      oldClipper.top != top || oldClipper.landscape != landscape;
}

class _GradientBloom extends StatelessWidget {
  const _GradientBloom();
  @override
  Widget build(BuildContext context) => RepaintBoundary(
          child: DecoratedBox(
        decoration: BoxDecoration(
            gradient: RadialGradient(
          center: Alignment(.75, -.65),
          radius: .85,
          colors: [
            Theme.of(context).colorScheme.secondary.withValues(alpha: .14),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0),
          ],
        )),
      ));
}
