import 'dart:async';
import 'dart:typed_data';

import 'package:better_phenikaa_schedule/features/giao_dien/bang_mau_anh/palette_extractor.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_generator.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_source.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_tokens.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phoi_mau/color_mixer.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_choice.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_manager.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tep_cuc_bo/file_bytes.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tep_cuc_bo/local_file_bridge.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CustomThemeEditor extends StatefulWidget {
  const new({this.existing, super.key});

  final CustomThemeDefinition? existing;

  @override
  State<CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends State<CustomThemeEditor> {
  static const int _maximumImageBytes = 20 * 1024 * 1024;

  final _nameController = TextEditingController();
  final _extractor = const PaletteExtractor();
  final _mixer = const ColorMixer();
  final _generator = const ThemeGenerator();

  ThemeSourceKind _kind = ThemeSourceKind.colorMix;
  List<Color> _colors = <Color>[
    const Color(0xFF1747B5),
    const Color(0xFF4A89FF),
    const Color(0xFF8B5CF6),
  ];
  List<double> _weights = <double>[60, 30, 10];
  List<ExtractedSwatch> _imageSwatches = <ExtractedSwatch>[];
  Uint8List? _imageBytes;
  String? _imagePath;
  String? _imageName;
  AppFontChoice _font = AppFontChoice.system;
  String? _previewFontFamily;
  ThemeTokens? _tokens;
  bool? _preferDark;
  double _radius = 16;
  bool _useThirdColor = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      _nameController.text = 'Theme của tôi';
      _regenerate();
      return;
    }
    _nameController.text = existing.name;
    _kind = existing.source.kind;
    _colors = existing.source.colors.isEmpty
        ? _colors
        : List<Color>.of(existing.source.colors);
    while (_colors.length < 3) {
      _colors.add(_colors.last);
    }
    _weights = existing.source.weights.isEmpty
        ? _weights
        : List<double>.of(existing.source.weights);
    while (_weights.length < 3) {
      _weights.add(10);
    }
    _useThirdColor = existing.source.colors.length >= 3;
    _imagePath = existing.source.imagePath;
    _imageSwatches = existing.source.colors
        .map((color) => ExtractedSwatch(color, 1))
        .toList();
    _font = existing.font;
    _tokens = existing.tokens;
    _preferDark = existing.tokens.dark;
    _radius = existing.tokens.radius;
    unawaited(_restoreManagedAssets());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _restoreManagedAssets() async {
    final resolved = await ThemeFontManager.instance.resolveFamily(_font);
    Uint8List? imageBytes;
    final path = _imagePath;
    if (path != null) {
      try {
        imageBytes = await readManagedFile(
          path,
          maximumBytes: _maximumImageBytes,
        );
      } on Object {
        imageBytes = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _previewFontFamily = resolved;
      _imageBytes = imageBytes;
      if (_font.kind == AppFontKind.imported && resolved == null) {
        _error = 'Font đã lưu không còn đọc được; đang dùng font mặc định.';
      }
    });
  }

  Future<void> _pickImage() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await LocalFileBridge.pick(LocalFileKind.image);
      if (file == null) return;
      final bytes = await readManagedFile(
        file.path,
        maximumBytes: _maximumImageBytes,
      );
      final swatches = await _extractor.extract(bytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imagePath = file.path;
        _imageName = file.name;
        _imageSwatches = swatches;
      });
      _regenerate();
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Không đọc được ảnh: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFont() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final imported = await ThemeFontManager.instance.importFont();
      if (imported == null || !mounted) return;
      setState(() {
        _font = imported;
        _previewFontFamily = imported.family;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Font không hợp lệ: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _regenerate() {
    try {
      if (_kind == ThemeSourceKind.image && _imageSwatches.isEmpty) {
        setState(() => _tokens = null);
        return;
      }
      final source = _kind == ThemeSourceKind.image
          ? _imageSwatches
          : _mixer.mix(
              _colors.take(_useThirdColor ? 3 : 2).toList(),
              _weights.take(_useThirdColor ? 3 : 2).toList(),
            );
      if (source.isEmpty) return;
      final tokens = _generator.generate(
        source,
        settings: ThemeGenerationSettings(
          preferDark: _preferDark,
          radius: _radius,
        ),
      );
      setState(() {
        _tokens = tokens;
        _error = null;
      });
    } on Object catch (error) {
      setState(() => _error = 'Không thể sinh theme: $error');
    }
  }

  Future<void> _chooseColor(int index) async {
    final selected = await showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RgbColorPicker(initial: _colors[index]),
    );
    if (selected == null) return;
    setState(() => _colors[index] = selected);
    _regenerate();
  }

  CustomThemeDefinition? _buildDefinition() {
    if (_kind == ThemeSourceKind.image && _imageSwatches.isEmpty) {
      setState(() => _error = 'Hãy chọn một ảnh hợp lệ trước khi lưu theme.');
      return null;
    }
    final tokens = _tokens;
    if (tokens == null) {
      setState(() => _error = 'Hãy chọn ảnh hoặc màu để tạo preview trước.');
      return null;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Hãy đặt tên cho theme.');
      return null;
    }
    final now = DateTime.now();
    final source = _kind == ThemeSourceKind.image
        ? ThemeSourceData.image(
            imagePath: _imagePath,
            colors: _imageSwatches.map((item) => item.color).toList(),
          )
        : ThemeSourceData.colorMix(
            colors: _colors.take(_useThirdColor ? 3 : 2).toList(),
            weights: _weights.take(_useThirdColor ? 3 : 2).toList(),
          );
    return CustomThemeDefinition(
      id: widget.existing?.id ?? 'theme_${now.microsecondsSinceEpoch}',
      name: name,
      source: source,
      tokens: tokens,
      font: _font,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save({required bool apply}) async {
    final definition = _buildDefinition();
    if (definition == null) return;
    setState(() => _busy = true);
    try {
      final controller = AppThemeController.instance;
      await controller.saveCustomTheme(definition);
      if (apply) await controller.applyCustomTheme(definition);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Không thể lưu theme: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = appThemePalette;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Tạo theme' : 'Sửa theme'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: <Widget>[
            TextField(
              controller: _nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Tên theme',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ThemeSourceKind>(
              segments: const <ButtonSegment<ThemeSourceKind>>[
                ButtonSegment(
                  value: ThemeSourceKind.image,
                  icon: Icon(Icons.image_outlined),
                  label: SizedBox(
                    width: 76,
                    child: Text(
                      'Ảnh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ButtonSegment(
                  value: ThemeSourceKind.colorMix,
                  icon: Icon(Icons.palette_outlined),
                  label: SizedBox(
                    width: 76,
                    child: Text(
                      'Phối màu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              selected: <ThemeSourceKind>{_kind},
              onSelectionChanged: (value) {
                setState(() => _kind = value.first);
                _regenerate();
              },
            ),
            const SizedBox(height: 14),
            if (_kind == ThemeSourceKind.image) _buildImageSource(active),
            if (_kind == ThemeSourceKind.colorMix) _buildColorSource(active),
            const SizedBox(height: 18),
            _SectionTitle('Chế độ sáng/tối'),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('Tự động'),
                  selected: _preferDark == null,
                  onSelected: (_) {
                    setState(() => _preferDark = null);
                    _regenerate();
                  },
                ),
                ChoiceChip(
                  label: const Text('Sáng'),
                  selected: _preferDark == false,
                  onSelected: (_) {
                    setState(() => _preferDark = false);
                    _regenerate();
                  },
                ),
                ChoiceChip(
                  label: const Text('Tối'),
                  selected: _preferDark == true,
                  onSelected: (_) {
                    setState(() => _preferDark = true);
                    _regenerate();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Bo góc: ${_radius.round()}'),
            Slider(
              value: _radius,
              max: 28,
              divisions: 14,
              onChanged: (value) {
                setState(() => _radius = value);
                _regenerate();
              },
            ),
            const SizedBox(height: 12),
            _SectionTitle('Font'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _font.kind == AppFontKind.imported
                  ? 'imported'
                  : _font.id,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: <DropdownMenuItem<String>>[
                for (final item in AppFontChoice.builtIns)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                if (_font.kind == AppFontKind.imported)
                  DropdownMenuItem(
                    value: 'imported',
                    child: Text(_font.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == 'imported') return;
                final choice = AppFontChoice.builtIns.firstWhere(
                  (item) => item.id == value,
                );
                setState(() {
                  _font = choice;
                  _previewFontFamily = choice.family;
                });
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _importFont,
              icon: const Icon(Icons.font_download_outlined),
              label: const Text('Nhập TTF / OTF từ máy'),
            ),
            const SizedBox(height: 20),
            _SectionTitle('Preview — chưa áp dụng'),
            if (_tokens case final tokens?)
              _ThemePreview(tokens: tokens, fontFamily: _previewFontFamily),
            if (_error case final error?) ...<Widget>[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: active.errorFallback)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _save(apply: false),
                  child: const Text(
                    'Lưu theme',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _save(apply: true),
                  child: Text(
                    _busy ? 'Đang xử lý…' : 'Lưu & Áp dụng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSource(AppThemePalette active) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_imageBytes case final bytes?)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              bytes,
              height: 150,
              fit: BoxFit.cover,
              cacheWidth: 1024,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 150,
                child: Center(child: Text('Không thể hiển thị ảnh preview')),
              ),
            ),
          )
        else
          Container(
            height: 130,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active.cardAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active.border),
            ),
            child: const Text(
              'Chưa chọn ảnh / screenshot / wallpaper',
              textAlign: TextAlign.center,
            ),
          ),
        if (_imageName != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(_imageName!, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _busy ? null : _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Chọn ảnh trên máy'),
        ),
        if (_imageSwatches.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _SwatchRow(colors: _imageSwatches.map((item) => item.color).toList()),
        ],
        const SizedBox(height: 6),
        Text(
          'Ảnh được giảm mẫu và phân tích ngay trên thiết bị; không tải lên server.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildColorSource(AppThemePalette active) {
    final count = _useThirdColor ? 3 : 2;
    return Column(
      children: <Widget>[
        for (var index = 0; index < count; index += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: () => _chooseColor(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _colors[index],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active.border, width: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 54,
                  child: Text('Màu ${String.fromCharCode(65 + index)}'),
                ),
                Expanded(
                  child: Slider(
                    value: _weights[index],
                    max: 100,
                    divisions: 20,
                    label: '${_weights[index].round()}%',
                    onChanged: (value) {
                      setState(() => _weights[index] = value);
                      _regenerate();
                    },
                  ),
                ),
                SizedBox(width: 42, child: Text('${_weights[index].round()}%')),
              ],
            ),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dùng màu thứ ba'),
          value: _useThirdColor,
          onChanged: (value) {
            setState(() => _useThirdColor = value);
            _regenerate();
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: heading?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const new({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Row(
    children: colors.take(8).map((color) {
      return Expanded(child: Container(height: 28, color: color));
    }).toList(),
  );
}

class _ThemePreview extends StatelessWidget {
  const new({required this.tokens, required this.fontFamily});

  final ThemeTokens tokens;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final fontScale = themeFontSizeFactor(fontFamily);
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      color: tokens.textPrimary,
      fontSize: 14 * fontScale,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[tokens.background, tokens.backgroundEnd],
        ),
        borderRadius: BorderRadius.circular(tokens.radius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Better Phenikaa App',
            style: baseStyle.copyWith(
              fontSize: 18 * fontScale,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(tokens.radius * 0.72),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.school_outlined, color: tokens.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Lập trình mobile',
                        style: baseStyle.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'A6-205 • 09:30–12:10',
                        style: baseStyle.copyWith(
                          color: tokens.textSecondary,
                          fontSize: 12 * fontScale,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Widget',
            style: baseStyle.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[tokens.widgetStart, tokens.widgetEnd],
              ),
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Kỹ thuật phần mềm',
                  style: baseStyle.copyWith(
                    color: tokens.widgetText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'A5-301 • 13:00–15:40',
                  style: baseStyle.copyWith(
                    color: tokens.widgetSubtext,
                    fontSize: 12 * fontScale,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RgbColorPicker extends StatefulWidget {
  const _RgbColorPicker({required this.initial});

  final Color initial;

  @override
  State<_RgbColorPicker> createState() => _RgbColorPickerState();
}

class _RgbColorPickerState extends State<_RgbColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  void _setHsv(HSVColor value) => setState(() => _hsv = value);

  void _setRgb({int? red, int? green, int? blue}) {
    final current = _color;
    final next = Color.fromARGB(
      255,
      red ?? (current.r * 255).round(),
      green ?? (current.g * 255).round(),
      blue ?? (current.b * 255).round(),
    );
    setState(() => _hsv = HSVColor.fromColor(next));
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final rgb = _color;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(
              palette.geometry == AppThemeGeometry.rounded ? 24 : 0,
            ),
          ),
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Chọn màu custom',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Kéo hoặc chạm trực tiếp trên bảng màu, hoặc chỉnh RGB.',
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 190,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, 190);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) =>
                          _setFromOffset(details.localPosition, size),
                      onPanDown: (details) =>
                          _setFromOffset(details.localPosition, size),
                      onPanUpdate: (details) =>
                          _setFromOffset(details.localPosition, size),
                      child: CustomPaint(
                        painter: _RgbSpectrumPainter(hueColor),
                        foregroundPainter: _RgbSelectionPainter(
                          _hsv.saturation,
                          _hsv.value,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _HueBar(
                hue: _hsv.hue,
                onChanged: (value) => _setHsv(_hsv.withHue(value)),
              ),
              const SizedBox(height: 10),
              _RgbSlider(
                label: 'R',
                value: (rgb.r * 255).round(),
                color: const Color(0xFFFF5A5A),
                onChanged: (value) => _setRgb(red: value),
              ),
              _RgbSlider(
                label: 'G',
                value: (rgb.g * 255).round(),
                color: const Color(0xFF5DDB7A),
                onChanged: (value) => _setRgb(green: value),
              ),
              _RgbSlider(
                label: 'B',
                value: (rgb.b * 255).round(),
                color: const Color(0xFF6DA9FF),
                onChanged: (value) => _setRgb(blue: value),
              ),
              const SizedBox(height: 10),
              Container(
                height: 48,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rgb,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  _colorHex(rgb),
                  style: TextStyle(
                    color: ThemeData.estimateBrightnessForColor(rgb) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(rgb),
                      child: const Text('Chọn'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setFromOffset(Offset offset, Size size) {
    _setHsv(
      _hsv
          .withSaturation((offset.dx / size.width).clamp(0.0, 1.0))
          .withValue((1 - offset.dy / size.height).clamp(0.0, 1.0)),
    );
  }
}

class _RgbSpectrumPainter extends CustomPainter {
  const _RgbSpectrumPainter(this.hue);

  final Color hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[Colors.white, hue],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RgbSpectrumPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _RgbSelectionPainter extends CustomPainter {
  const _RgbSelectionPainter(this.saturation, this.value);

  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * saturation, size.height * (1 - value));
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      center,
      5.5,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _RgbSelectionPainter oldDelegate) =>
      oldDelegate.saturation != saturation || oldDelegate.value != value;
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: Stack(
      alignment: Alignment.center,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 0,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            overlayColor: Colors.white24,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: hue,
            max: 360,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 22,
          child: Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            activeColor: color,
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}

String _colorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

extension on AppThemePalette {
  Color get errorFallback =>
      dark ? const Color(0xFFFF8A90) : const Color(0xFFB3261E);
}
