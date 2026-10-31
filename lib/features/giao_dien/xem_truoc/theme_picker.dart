import 'dart:async';

import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_source.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_choice.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_manager.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/tien_mon_premium/tien_mon_premium_contract.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/xem_truoc/custom_theme_editor.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';

const _presetIds = <AppThemeId>[
  AppThemeId.classic,
  AppThemeId.lol,
  AppThemeId.valorant,
  AppThemeId.minecraft,
  AppThemeId.facebook,
  AppThemeId.shopee,
  AppThemeId.tiktok,
  AppThemeId.ben10,
  AppThemeId.youtube,
  AppThemeId.steam,
];

Future<void> showAppThemePicker(BuildContext context) async {
  final controller = AppThemeController.instance;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ThemePickerSheet(controller: controller),
    ),
  );
}

class _ThemePickerSheet extends StatelessWidget {
  const new({required this.controller});

  final AppThemeController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    final radius = palette.geometry == AppThemeGeometry.rounded ? 28.0 : 0.0;
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.86,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.shadow,
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: palette.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Giao diện',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: themeLetterSpacing(palette),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Preset cũ được giữ nguyên. Theme mới chỉ áp dụng sau khi bạn xác nhận.',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomThemeEditor(),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Tạo theme từ ảnh hoặc phối màu'),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(child: _heading('Preset có sẵn', palette)),
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 9),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.45,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _PresetCard(
                          id: _presetIds[index],
                          selected: controller.theme == _presetIds[index],
                          onTap: () =>
                              _selectPreset(context, _presetIds[index]),
                        ),
                        childCount: _presetIds.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 16),
                      child: SizedBox(
                        height: 142,
                        child: _PresetCard(
                          id: AppThemeId.tienMonPremium,
                          selected:
                              controller.theme == AppThemeId.tienMonPremium,
                          onTap: () =>
                              _selectPreset(context, AppThemeId.tienMonPremium),
                        ),
                      ),
                    ),
                  ),
                  if (controller.theme == AppThemeId.tienMonPremium) ...<Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showTienMonFontPicker(context),
                            icon: const Icon(Icons.font_download_outlined),
                            label: Text(
                              'Khẩu Quyết · ${controller.tienMonFont.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showTienMonFontColors(context),
                            icon: const Icon(Icons.format_color_text_rounded),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Text('Bản Môn Sắc Diện  '),
                                _FontColorChip(
                                  label: 'A',
                                  color: controller.tienMonTextPrimary,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('|'),
                                ),
                                _FontColorChip(
                                  label: 'B',
                                  color: controller.tienMonTextSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: _heading(
                      'Theme đã lưu (${controller.customThemes.length})',
                      palette,
                    ),
                  ),
                  if (controller.customThemes.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Chưa có theme tùy chỉnh.',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final theme = controller.customThemes[index];
                        return _CustomThemeCard(
                          theme: theme,
                          selected:
                              controller.activeCustomTheme?.id == theme.id,
                          onApply: () => _applyCustomTheme(context, theme),
                          onEdit: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CustomThemeEditor(existing: theme),
                            ),
                          ),
                          onDelete: () => _confirmDelete(context, theme),
                        );
                      }, childCount: controller.customThemes.length),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTienMonFontPicker(BuildContext context) async {
    const presets = <AppFontChoice>[
      AppThemeController.tienMonDefaultFont,
      AppFontChoice.system,
      AppFontChoice(
        id: 'serif',
        label: 'Serif cổ điển',
        kind: AppFontKind.builtIn,
        family: 'serif',
      ),
      AppFontChoice(
        id: 'monospace',
        label: 'Monospace',
        kind: AppFontKind.builtIn,
        family: 'monospace',
      ),
      AppFontChoice(
        id: 'minecraft',
        label: 'Minecraft',
        kind: AppFontKind.builtIn,
        family: 'MinecraftCustom',
      ),
    ];

    var selected = controller.tienMonFont;
    String? error;
    var busy = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> apply(AppFontChoice choice) async {
            if (busy) return;
            setSheetState(() {
              busy = true;
              error = null;
            });
            try {
              await controller.setTienMonFont(choice);
              if (!sheetContext.mounted) return;
              setSheetState(() => selected = controller.tienMonFont);
            } on Object catch (e) {
              if (sheetContext.mounted) {
                setSheetState(() => error = 'Không áp dụng được font: $e');
              }
            } finally {
              if (sheetContext.mounted) setSheetState(() => busy = false);
            }
          }

          Future<void> importFont() async {
            if (busy) return;
            setSheetState(() {
              busy = true;
              error = null;
            });
            try {
              final imported = await ThemeFontManager.instance.importFont();
              if (imported == null || !sheetContext.mounted) return;
              await controller.setTienMonFont(imported);
              if (!sheetContext.mounted) return;
              setSheetState(() => selected = controller.tienMonFont);
            } on Object catch (e) {
              if (sheetContext.mounted) {
                setSheetState(() => error = 'Font không hợp lệ: $e');
              }
            } finally {
              if (sheetContext.mounted) setSheetState(() => busy = false);
            }
          }

          final importedSelected = selected.kind == AppFontKind.imported;
          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF102820),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0x99FFD66B))),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Khẩu Quyết',
                      style: TextStyle(
                        color: Color(0xFFFFD66B),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chỉ áp dụng khi đang dùng Tiên Môn Premium.',
                      style: TextStyle(color: Color(0xFFD5E9DF)),
                    ),
                    const SizedBox(height: 14),
                    for (final choice in presets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: selected.id == choice.id
                                  ? const Color(0xFFFFD66B)
                                  : Colors.white24,
                            ),
                          ),
                          tileColor: Colors.white.withValues(alpha: .035),
                          title: Text(
                            choice.label,
                            style: TextStyle(
                              fontFamily: choice.family,
                              color: const Color(0xFFFFE7A6),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          trailing: selected.id == choice.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFFFFD66B),
                                )
                              : null,
                          onTap: busy ? null : () => apply(choice),
                        ),
                      ),
                    if (importedSelected)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFFFD66B)),
                          ),
                          tileColor: Colors.white.withValues(alpha: .035),
                          title: Text(
                            selected.label,
                            style: TextStyle(
                              fontFamily: controller.tienMonFontFamily,
                              color: const Color(0xFFFFE7A6),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: const Text(
                            'Font đã nhập từ máy',
                            style: TextStyle(color: Color(0xFFB8CFC4)),
                          ),
                          trailing: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFFFD66B),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : importFont,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(
                          busy ? 'Đang xử lý…' : 'Nhập TTF / OTF từ máy',
                        ),
                      ),
                    ),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFFF9A9A)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTienMonFontColors(BuildContext context) async {
    var primary = controller.tienMonTextPrimary;
    var secondary = controller.tienMonTextSecondary;
    final primaryHex = TextEditingController(text: _colorHex(primary));
    final secondaryHex = TextEditingController(text: _colorHex(secondary));
    const choices = <Color>[
      Color(0xFFFFD66B),
      Color(0xFFFFE7A6),
      Color(0xFFFFFFFF),
      Color(0xFFB8FFE5),
      Color(0xFF74D8B1),
      Color(0xFFBFE8FF),
      Color(0xFFFFC9D8),
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget editor(
            String label,
            Color selected,
            TextEditingController hexController,
            ValueChanged<Color> onChanged,
          ) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _FontColorChip(label: label, color: selected),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label == 'A' ? 'Màu chữ chính' : 'Màu chữ phụ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: <Widget>[
                    ...choices.map(
                      (color) => InkWell(
                        onTap: () {
                          onChanged(color);
                          hexController.text = _colorHex(color);
                        },
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.toARGB32() == selected.toARGB32()
                                  ? Colors.white
                                  : Colors.white24,
                              width: color.toARGB32() == selected.toARGB32()
                                  ? 3
                                  : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final color = await showModalBottomSheet<Color>(
                          context: sheetContext,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _RgbColorPicker(initial: selected),
                        );
                        if (color == null) return;
                        onChanged(color);
                        hexController.text = _colorHex(color);
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: hexController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Mã màu $label',
                    hintText: '#FFD66B',
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                  onChanged: (value) {
                    final color = _parseHexColor(value);
                    if (color != null) onChanged(color);
                  },
                ),
              ],
            );
          }

          return SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF102820),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0x99FFD66B))),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Bản Môn Sắc Diện  [ A | B ]',
                      style: TextStyle(
                        color: Color(0xFFFFD66B),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    editor(
                      'A',
                      primary,
                      primaryHex,
                      (color) => setSheetState(() => primary = color),
                    ),
                    const SizedBox(height: 18),
                    editor(
                      'B',
                      secondary,
                      secondaryHex,
                      (color) => setSheetState(() => secondary = color),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final parsedPrimary =
                              _parseHexColor(primaryHex.text) ?? primary;
                          final parsedSecondary =
                              _parseHexColor(secondaryHex.text) ?? secondary;
                          await controller.setTienMonTextColors(
                            parsedPrimary,
                            parsedSecondary,
                          );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        child: const Text('Áp dụng'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    primaryHex.dispose();
    secondaryHex.dispose();
  }

  Future<void> _selectPreset(BuildContext context, AppThemeId id) async {
    if (controller.theme == id) return;

    if (controller.theme == AppThemeId.tienMonPremium &&
        id != AppThemeId.tienMonPremium) {
      await _leaveTienMon(
        context,
        () => controller.select(id),
      );
      return;
    }

    if (id != AppThemeId.tienMonPremium) {
      await controller.select(id);
      return;
    }

    // Keep the loading cover fully opaque while Premium warms up. The previous
    // flow started changing the theme as soon as the dialog route was pushed,
    // so a slow first background decode could briefly expose the intermediate
    // Theme Engine layer. Precache the first scene, wait for the final Premium
    // frame, then reverse-fade the loading cover away.
    final presented = Completer<void>();
    unawaited(
      showGeneralDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 240),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final opacity = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: opacity, child: child);
        },
        pageBuilder: (_, _, _) => _TienMonThemeLoading(
          onPresented: () {
            if (!presented.isCompleted) presented.complete();
          },
        ),
      ),
    );

    try {
      await presented.future;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Mount Premium immediately under the loading cover. The wallpaper
      // now decodes asynchronously at the display target size and fades in on
      // its first frame, so selecting the theme never waits on a 2K decode.
      await controller.select(id);
      await WidgetsBinding.instance.endOfFrame;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _applyCustomTheme(
    BuildContext context,
    CustomThemeDefinition theme,
  ) async {
    if (controller.theme == AppThemeId.tienMonPremium) {
      await _leaveTienMon(
        context,
        () => controller.applyCustomTheme(theme),
      );
      return;
    }
    await controller.applyCustomTheme(theme);
  }

  Future<void> _leaveTienMon(
    BuildContext context,
    Future<void> Function() applyTarget,
  ) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNavigator.context;

    // Close the theme picker first so the loading screen fades back into the
    // actual app, not back into the picker sheet.
    Navigator.of(context).pop();
    await WidgetsBinding.instance.endOfFrame;

    final presented = Completer<void>();
    unawaited(
      showGeneralDialog<void>(
        context: rootContext,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: Colors.white,
        transitionDuration: const Duration(milliseconds: 240),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final opacity = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: opacity, child: child);
        },
        pageBuilder: (_, _, _) => _DefaultThemeLoading(
          onPresented: () {
            if (!presented.isCompleted) presented.complete();
          },
        ),
      ),
    );

    try {
      await presented.future;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await applyTarget();

      // Hold the default loading cover until the Theme Engine target has
      // mounted and painted, then fade cleanly into the app.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    } finally {
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }
  }

  Widget _heading(String label, AppThemePalette palette) => Text(
    label,
    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
  );

  Future<void> _confirmDelete(
    BuildContext context,
    CustomThemeDefinition theme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa theme?'),
        content: Text('“${theme.name}” sẽ bị xóa khỏi thiết bị.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteCustomTheme(theme.id);
  }
}

String _colorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? _parseHexColor(String raw) {
  var value = raw.trim().replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
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
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    final rgb = _color;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xFF102820),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0x99FFD66B))),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Chọn màu RGB',
                style: TextStyle(
                  color: Color(0xFFFFD66B),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
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
                      onTapDown: (details) => _setFromOffset(
                        details.localPosition,
                        size,
                      ),
                      onPanDown: (details) => _setFromOffset(
                        details.localPosition,
                        size,
                      ),
                      onPanUpdate: (details) => _setFromOffset(
                        details.localPosition,
                        size,
                      ),
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
                  border: Border.all(color: Colors.white38),
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
    child: LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
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
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                ),
              ),
              child: Slider(
                value: hue,
                max: 360,
                onChanged: onChanged,
              ),
            ),
          ],
        );
      },
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
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(
        width: 22,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFFE7A6),
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
          style: const TextStyle(color: Color(0xFFD5E9DF)),
        ),
      ),
    ],
  );
}

class _FontColorChip extends StatelessWidget {
  const _FontColorChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: Colors.white30),
      boxShadow: const <BoxShadow>[
        BoxShadow(color: Color(0x55000000), blurRadius: 4),
      ],
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    ),
  );
}

class _DefaultThemeLoading extends StatefulWidget {
  const _DefaultThemeLoading({required this.onPresented});

  final VoidCallback onPresented;

  @override
  State<_DefaultThemeLoading> createState() => _DefaultThemeLoadingState();
}

class _DefaultThemeLoadingState extends State<_DefaultThemeLoading> {
  static final AppThemePalette _palette =
      appThemePalettes[AppThemeId.classic]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPresented();
    });
  }

  @override
  Widget build(BuildContext context) => Material(
    color: _palette.surface,
    child: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _palette.primary,
                  width: 6,
                ),
              ),
              child: Icon(
                AppThemeId.classic.icon,
                size: 44,
                color: _palette.primary,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Better Phenikaa App',
              style: TextStyle(
                color: _palette.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '2.1.2 • Lịch học & Lịch thi',
              style: TextStyle(
                color: _palette.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 120),
            SizedBox(
              width: 88,
              child: LinearProgressIndicator(
                minHeight: 4,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: _palette.cardAlt,
                color: _palette.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Đang khởi động...',
              style: TextStyle(
                color: _palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TienMonThemeLoading extends StatefulWidget {
  const _TienMonThemeLoading({required this.onPresented});

  final VoidCallback onPresented;

  @override
  State<_TienMonThemeLoading> createState() => _TienMonThemeLoadingState();
}

class _TienMonThemeLoadingState extends State<_TienMonThemeLoading> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPresented();
    });
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF0B211C),
    child: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFFFFD66B),
              size: 56,
            ),
            const SizedBox(height: 18),
            const Text(
              'Tiên Môn Premium',
              style: TextStyle(
                color: Color(0xFFFFD66B),
                fontSize: 27,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Đang mở Tiên Môn...',
              style: TextStyle(
                color: Color(0xFFD5E9DF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 118,
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Color(0x553A7964),
                color: Color(0xFFFFD66B),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PresetCard extends StatelessWidget {
  const new({required this.id, required this.selected, required this.onTap});

  final AppThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = appThemePalette;
    final preview = appThemePalettes[id]!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active.card,
          borderRadius: BorderRadius.circular(
            active.geometry == AppThemeGeometry.rounded ? 14 : 2,
          ),
          border: Border.all(
            color: selected ? active.primary : active.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      preview.pageStart,
                      preview.primary,
                      preview.accent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    preview.geometry == AppThemeGeometry.rounded ? 9 : 1,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      selected ? Icons.check_circle_rounded : id.icon,
                      color: preview.widgetText,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              id.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            Text(
              id.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: active.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomThemeCard extends StatelessWidget {
  const new({
    required this.theme,
    required this.selected,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomThemeDefinition theme;
  final bool selected;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = appThemePalette;
    final tokens = theme.tokens;
    return Card(
      margin: const EdgeInsets.only(top: 9),
      child: ListTile(
        onTap: onApply,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[tokens.primary, tokens.accent],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? active.primary : active.border,
              width: 2,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, color: tokens.widgetText)
              : null,
        ),
        title: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${theme.source.kind == ThemeSourceKind.image ? 'Ảnh' : 'Phối màu'} • ${theme.font.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}

class AppThemeSettingButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final palette = controller.palette;
        final label =
            controller.activeCustomTheme?.name ?? controller.theme.label;
        return AppThemePanel(
          elevated: false,
          alt: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: () => showAppThemePicker(context),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[palette.primary, palette.accent],
                    ),
                    borderRadius: BorderRadius.circular(
                      palette.geometry == AppThemeGeometry.rounded ? 10 : 1,
                    ),
                  ),
                  child: Icon(
                    controller.theme.icon,
                    color: palette.widgetText,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Giao diện',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}
