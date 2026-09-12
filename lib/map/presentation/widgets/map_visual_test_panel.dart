import 'dart:async';

import 'package:flutter/material.dart';
import 'package:autth_injustice_app/map/presentation/widgets/campus_map_viewport.dart';

/// Painel temporario de calibracao; permanece aberto enquanto o mapa se move.
class MapVisualTestPanel extends StatefulWidget {
  final CampusMapViewportState viewport;
  final VoidCallback onClose;

  const MapVisualTestPanel({
    super.key,
    required this.viewport,
    required this.onClose,
  });

  @override
  State<MapVisualTestPanel> createState() => _MapVisualTestPanelState();
}

class _MapVisualTestPanelState extends State<MapVisualTestPanel> {
  Map<String, dynamic>? _values;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final values = await widget.viewport.visualTestSettings();
      if (mounted) {
        setState(() {
          _values = values;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível ler os ajustes.');
    }
  }

  Widget _slider(String label, String key, double min, double max,
      {Future<void> Function(double)? apply}) {
    final value = ((_values![key] as num?)?.toDouble() ?? min).clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text(value.toStringAsFixed(2),
              style: const TextStyle(color: Color(0xFFB9CBFF))),
        ]),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 40,
          onChanged: (next) => setState(() => _values![key] = next),
          onChangeEnd: (next) => unawaited(apply != null
              ? apply(next)
              : widget.viewport.configureNightLook({key: next})),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children, {bool open = false}) =>
      ExpansionTile(
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        initiallyExpanded: open,
        tilePadding: EdgeInsets.zero,
        children: children,
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFAB91FF), brightness: Brightness.dark),
        sliderTheme: const SliderThemeData(trackHeight: 2),
      ),
      child: Material(
        color: const Color(0xF20D1423),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(children: [
              const Expanded(
                  child: Text('Laboratório da noite',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                  tooltip: 'Fechar ajustes',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close)),
            ]),
          ),
          Expanded(
              child: _values == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _load,
                              child: Text('$_error Tentar novamente')))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Text(
                            'Solte o controle para aplicar. Ajustes temporários.',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white60)),
                        Wrap(spacing: 8, children: [
                          ActionChip(
                              label: const Text('Meia-noite'),
                              onPressed: () async {
                                await widget.viewport.previewTime(0);
                                await _load();
                              }),
                          ActionChip(
                              label: const Text('Hora atual'),
                              onPressed: () async {
                                final now = DateTime.now();
                                await widget.viewport
                                    .setPreviewLocalTimeMinutes(
                                        now.hour * 60 + now.minute);
                                await widget.viewport.previewTime(null);
                                await _load();
                              }),
                        ]),
                        _section(
                            'Iluminação',
                            [
                              _slider('Exposição', 'exposure', 0.25, 1.2),
                              _slider('Luz da lua', 'moonlight', 0, 6),
                              _slider('Luz ambiente', 'ambient', 0, 0.2),
                              _slider('Luz do céu', 'hemisphere', 0, 0.6),
                              _slider('Luz nas sombras', 'fill', 0, 1),
                              _slider('Janelas acesas', 'windows', 0, 4),
                              _slider('Luz espalhada das janelas',
                                  'windowSpill', 0, 3),
                              _slider('Feixes da lua', 'moonShafts', 0, 2),
                            ],
                            open: true),
                        _section('Reflexos e texturas', [
                          _slider(
                              'Claridade da grama', 'grassBrightness', 0, 0.3),
                          _slider(
                              'Intensidade dos reflexos', 'reflections', 0, 3),
                          _slider('Reflexo do piso', 'floorReflection', 0, 4),
                          _slider(
                              'Rugosidade do piso', 'floorRoughness', 0.07, 1),
                          _slider('Piso molhado', 'wetness', 0, 1),
                          _slider('Relevo das texturas', 'textureDetail', 0, 2),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Detalhes das superfícies'),
                            subtitle: const Text(
                                'Grãos, relevo e variação do acabamento.'),
                            value: _values!['textures'] == true,
                            onChanged: (value) {
                              setState(() => _values!['textures'] = value);
                              unawaited(widget.viewport
                                  .configureNightLook({'textures': value}));
                            },
                          ),
                        ]),
                        _section('Brilho e cores', [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Halo das luzes'),
                            subtitle: const Text(
                                'Efeito extra; pode reduzir a fluidez.'),
                            value: _values!['bloom'] == true,
                            onChanged: (value) {
                              setState(() => _values!['bloom'] = value);
                              unawaited(widget.viewport
                                  .configureBloom({'enabled': value}));
                            },
                          ),
                          _slider('Força do halo', 'bloomStrength', 0, 1,
                              apply: (value) => widget.viewport
                                  .configureBloom({'strength': value})),
                          DropdownButton<String>(
                            isExpanded: true,
                            value: _values!['toneMapping'] as String? ?? 'aces',
                            items: const [
                              DropdownMenuItem(
                                  value: 'aces',
                                  child: Text('Cores · Cinema (ACES)')),
                              DropdownMenuItem(
                                  value: 'agx',
                                  child: Text('Cores · Suave (AgX)')),
                              DropdownMenuItem(
                                  value: 'neutral',
                                  child: Text('Cores · Neutro')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _values!['toneMapping'] = value);
                              unawaited(widget.viewport.setToneMapping(value));
                            },
                          ),
                        ]),
                        _section('Resolução e sombras', [
                          _slider('Nitidez parado', 'resting', 0.5, 4,
                              apply: widget.viewport.setRestingRenderScale),
                          _slider('Nitidez em movimento', 'moving', 0.5, 4,
                              apply: widget.viewport.setInteractionRenderScale),
                          DropdownButton<int>(
                            isExpanded: true,
                            value: (_values!['shadows'] as num?)?.toInt() ?? 0,
                            items: [
                              for (final size in [0, 1024, 2048, 4096, 8192])
                                DropdownMenuItem(
                                    value: size,
                                    child: Text(size == 0
                                        ? 'Sombras desligadas'
                                        : 'Sombras · $size'))
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _values!['shadows'] = value);
                              unawaited(
                                  widget.viewport.setShadowMapSize(value));
                            },
                          ),
                        ]),
                        TextButton.icon(
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Restaurar aparência noturna'),
                          onPressed: () async {
                            await widget.viewport.resetNightLook();
                            await _load();
                          },
                        ),
                      ],
                    )),
        ]),
      ),
    );
  }
}
