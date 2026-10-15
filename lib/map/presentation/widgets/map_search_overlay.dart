import 'dart:async';
import 'dart:math' as math;

import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/responsive/app_responsive.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/map/domain/models/map_event_entry.dart';
import 'package:autth_injustice_app/map/domain/models/map_location.dart';
import 'package:autth_injustice_app/map/domain/models/map_search_index.dart';
import 'package:flutter/material.dart';

class MapSearchOverlay extends StatefulWidget {
  final List<MapLocation> locations;
  final List<MapEventEntry> events;
  final ValueChanged<MapSearchResult> onSelected;

  const MapSearchOverlay({
    super.key,
    required this.locations,
    required this.events,
    required this.onSelected,
  });

  @override
  State<MapSearchOverlay> createState() => _MapSearchOverlayState();
}

class _MapSearchOverlayState extends State<MapSearchOverlay>
    with SingleTickerProviderStateMixin {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final AnimationController _reveal;
  late final CurvedAnimation _curve;
  late MapSearchIndex _index;
  List<MapSearchResult> _results = const [];
  String _signature = '';
  String? _selectedId;
  Timer? _debounce;
  bool _open = false;
  bool _choosing = false;
  int _choiceEpoch = 0;

  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _index = MapSearchIndex(widget.locations, widget.events);
    _refreshResults();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 210),
    );
    _curve = CurvedAnimation(
      parent: _reveal,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(MapSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSources(oldWidget)) {
      _index = MapSearchIndex(widget.locations, widget.events);
      _refreshResults();
    }
  }

  bool _sameSources(MapSearchOverlay previous) {
    if (previous.locations.length != widget.locations.length ||
        previous.events.length != widget.events.length) {
      return false;
    }
    for (var index = 0; index < widget.locations.length; index++) {
      final a = previous.locations[index], b = widget.locations[index];
      if (a != b || a.label != b.label) return false;
    }
    for (var index = 0; index < widget.events.length; index++) {
      final a = previous.events[index], b = widget.events[index];
      if (a.event.id != b.event.id ||
          a.event.title != b.event.title ||
          a.locations.length != b.locations.length) {
        return false;
      }
      for (var place = 0; place < a.locations.length; place++) {
        if (a.locations[place] != b.locations[place] ||
            a.locations[place].label != b.locations[place].label) {
          return false;
        }
      }
    }
    return true;
  }

  void _refreshResults() {
    _results = _index.search(_field.text);
    _signature = _results.map((result) => result.id).join('|');
  }

  void _queryChanged(String _) {
    _debounce?.cancel();
    // Coalesce fast typing; nothing in the WebView is rebuilt per keystroke.
    _debounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      setState(_refreshResults);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _show() {
    if (_choosing) return;
    _choiceEpoch++;
    _debounce?.cancel();
    setState(() {
      _open = true;
      _selectedId = null;
      _field.clear();
      _refreshResults();
    });
    if (_reducedMotion) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
    // Focus on the first frame, not after the opening animation has finished.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open && !_choosing) _focus.requestFocus();
    });
  }

  Future<bool> _hide() async {
    _debounce?.cancel();
    if (_open) setState(() => _open = false);
    _focus.unfocus();
    if (_reducedMotion) {
      _reveal.value = 0;
      return true;
    }
    try {
      await _reveal.reverse().orCancel;
      return true;
    } on TickerCanceled {
      return false;
    }
  }

  void _dismiss() {
    _choiceEpoch++;
    _choosing = false;
    unawaited(_hide());
  }

  Future<void> _choose(MapSearchResult result) async {
    if (_choosing ||
        !_open ||
        !_index.search(_field.text).any((current) => current.id == result.id)) {
      return;
    }
    _debounce?.cancel();
    final epoch = ++_choiceEpoch;
    setState(() {
      _choosing = true;
      _selectedId = result.id;
    });
    if (!_reducedMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 85));
    }
    if (!mounted || epoch != _choiceEpoch) return;
    final closed = await _hide();
    if (!mounted || !closed || epoch != _choiceEpoch) return;
    setState(() => _choosing = false);
    widget.onSelected(result);
  }

  @override
  void dispose() {
    _choiceEpoch++;
    _debounce?.cancel();
    _curve.dispose();
    _reveal.dispose();
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final surface = dark ? const Color(0xFF090A0D) : Colors.white;
    final ink = dark ? Colors.white : Colors.black;
    final scale = context.responsive.layoutScale;
    final buttonSize = (46 * scale).clamp(42.0, 48.0);
    final margin = context.responsive.pageHorizontalPadding;
    final motion =
        _reducedMotion ? Duration.zero : const Duration(milliseconds: 180);
    final results = _results;

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) _dismiss();
      },
      child: LayoutBuilder(builder: (context, constraints) {
        final media = MediaQuery.of(context);
        // Avoid double keyboard padding if a host already resizes its body.
        final covered = (media.viewInsets.bottom -
                math.max(0, media.size.height - constraints.maxHeight))
            .clamp(0.0, media.viewInsets.bottom);
        final top = media.padding.top + 14;
        final available = math.max(0.0,
            constraints.maxHeight - top - covered - 12 - media.padding.bottom);
        final width = math.min(
            520.0, math.max(buttonSize, constraints.maxWidth - margin * 2));
        final height = math.min(440.0, available);
        final fieldHeight = math.min(
            available, math.max(54.0, media.textScaler.scale(14) * 1.4 + 32));

        return Stack(children: [
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('map-search-dismiss'),
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
              ),
            ),
          Positioned(
            top: top,
            right: margin,
            width: width,
            child: AnimatedBuilder(
              animation: _curve,
              builder: (context, panel) => Stack(
                alignment: Alignment.topRight,
                children: [
                  IgnorePointer(
                    ignoring: _open || _choosing,
                    child: Opacity(
                      opacity: 1 - _curve.value,
                      child: SizedBox.square(
                        dimension: buttonSize,
                        child: Material(
                          color: surface,
                          borderRadius: BorderRadius.circular(15 * scale),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            key: const ValueKey('map-search-open'),
                            tooltip: context.l10n.mapSearch,
                            onPressed: _show,
                            icon: Icon(Icons.search_rounded,
                                color: ink,
                                size: 22 * context.responsive.iconScale),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_curve.value > 0 || _open)
                    IgnorePointer(
                      ignoring: !_open || _choosing,
                      child: ClipRect(
                        child: Align(
                          key: const ValueKey('map-search-reveal'),
                          alignment: Alignment.topRight,
                          widthFactor: _curve.value,
                          child: FadeTransition(opacity: _curve, child: panel),
                        ),
                      ),
                    ),
                ],
              ),
              child: SizedBox(
                width: width,
                height: math.max(fieldHeight, height),
                child: RepaintBoundary(
                  child: Column(children: [
                    SizedBox(
                      height: fieldHeight,
                      child: Material(
                        color: surface,
                        borderRadius: BorderRadius.circular(18),
                        child: TextField(
                          key: const ValueKey('map-search-field'),
                          controller: _field,
                          focusNode: _focus,
                          readOnly: _choosing,
                          style: context.bodyMedium
                              ?.copyWith(color: ink, fontSize: 14),
                          cursorColor: ink,
                          textInputAction: TextInputAction.search,
                          onChanged: _queryChanged,
                          onSubmitted: (_) {
                            _debounce?.cancel();
                            setState(_refreshResults);
                            if (_results.isNotEmpty) {
                              unawaited(_choose(_results.first));
                            }
                          },
                          decoration: InputDecoration(
                            hintText: context.l10n.mapSearchHint,
                            hintStyle: TextStyle(
                                color: ink.withValues(alpha: .48),
                                fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: ink, size: 21),
                            suffixIcon: IconButton(
                              key: const ValueKey('map-search-close'),
                              tooltip: context.l10n.mapSearchClose,
                              onPressed: _dismiss,
                              icon: Icon(Icons.close_rounded,
                                  color: ink, size: 20),
                            ),
                            filled: false,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    if (height > fieldHeight + 24) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: height - fieldHeight - 8),
                        child: _SearchPanelResize(
                          duration: motion,
                          child: Material(
                            color: surface,
                            borderRadius: BorderRadius.circular(19),
                            clipBehavior: Clip.antiAlias,
                            child: AnimatedSwitcher(
                              duration: motion,
                              reverseDuration: _reducedMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 120),
                              layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    if (previous.isNotEmpty)
                                      IgnorePointer(
                                          child: ExcludeSemantics(
                                              child: previous.last)),
                                    if (current != null) current,
                                  ]),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                          begin: const Offset(.035, .025),
                                          end: Offset.zero)
                                      .animate(animation),
                                  child: child,
                                ),
                              ),
                              child: results.isEmpty
                                  ? SizedBox(
                                      key: const ValueKey('map-search-empty'),
                                      height: 86,
                                      child: Center(
                                          child: Padding(
                                              padding: const EdgeInsets.all(18),
                                              child: Text(
                                                  context.l10n.mapSearchEmpty,
                                                  style: context.bodySmall
                                                      ?.copyWith(
                                                          color: ink.withValues(
                                                              alpha: .6))))))
                                  : ListView.separated(
                                      key: ValueKey(_signature),
                                      controller: _scroll,
                                      primary: false,
                                      // Only measure the complete list when it
                                      // has at most four rows. Large lists stay lazy.
                                      shrinkWrap: results.length <= 4,
                                      padding: const EdgeInsets.all(8),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .manual,
                                      itemCount: results.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 5),
                                      itemBuilder: (_, index) {
                                        final result = results[index];
                                        return _MapSearchTile(
                                          key: ValueKey(result.id),
                                          result: result,
                                          selected: _selectedId == result.id,
                                          onTap: () =>
                                              unawaited(_choose(result)),
                                        );
                                      },
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _SearchPanelResize extends StatelessWidget {
  final Duration duration;
  final Widget child;
  const _SearchPanelResize({required this.duration, required this.child});

  @override
  Widget build(BuildContext context) => duration == Duration.zero
      ? child
      : AnimatedSize(
          duration: duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: child,
        );
}

class _MapSearchTile extends StatelessWidget {
  final MapSearchResult result;
  final bool selected;
  final VoidCallback onTap;
  const _MapSearchTile(
      {super.key,
      required this.result,
      required this.selected,
      required this.onTap});

  static const _palette = [
    (Color(0xFFE17078), Color(0xFFAD505B)),
    (Color(0xFFAA7BC7), Color(0xFF8053A8)),
    (Color(0xFFD77FA8), Color(0xFFAC557E)),
    (Color(0xFF769CC8), Color(0xFF4C78A8)),
    (Color(0xFF62AAA3), Color(0xFF3E817A)),
    (Color(0xFFCC9E60), Color(0xFF926B38)),
  ];

  static const _titleShadows = [
    Shadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 1)),
  ];
  static const _subtitleShadows = [
    Shadow(color: Color(0x4D000000), blurRadius: 7, offset: Offset(0, 1)),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final ink = result.isEvent || dark ? Colors.white : Colors.black;
    final seed = (result.eventId ?? '')
        .codeUnits
        .fold(0, (hash, value) => (hash * 31 + value) & 0x7fffffff);
    final pair = _palette[seed % _palette.length];
    final color = result.isEvent
        ? (dark ? pair.$2 : pair.$1)
        : (dark ? const Color(0xFF17181D) : const Color(0xFFF3F3F5));
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 90),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(ink.withValues(alpha: .15), color)
              : color,
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashFactory: NoSplash.splashFactory,
            highlightColor: ink.withValues(alpha: .10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 84),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(children: [
                  Icon(
                      result.isEvent
                          ? Icons.event_rounded
                          : result.destination.spaceNodeName != null
                              ? Icons.meeting_room_outlined
                              : result.destination.floorId != null
                                  ? Icons.layers_outlined
                                  : Icons.place_outlined,
                      size: 20,
                      color: ink.withValues(alpha: .85)),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text(result.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.bodyMedium?.copyWith(
                                color: ink,
                                shadows: result.isEvent ? _titleShadows : null,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        if (result.origin != null) ...[
                          const SizedBox(height: 5),
                          Text(result.origin!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.bodySmall?.copyWith(
                                  color: ink.withValues(alpha: .55),
                                  shadows:
                                      result.isEvent ? _subtitleShadows : null,
                                  fontSize: 12)),
                        ],
                      ])),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
