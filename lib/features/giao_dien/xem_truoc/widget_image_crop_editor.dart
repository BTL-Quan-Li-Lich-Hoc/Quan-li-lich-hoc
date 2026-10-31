import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/widget_theme_configuration.dart';
import 'package:flutter/material.dart';

/// Selects a region without rewriting or downsampling the original photo.
class WidgetImageCropEditor extends StatefulWidget {
  const new({required this.bytes, required this.aspectRatio, super.key});

  final Uint8List bytes;
  final double aspectRatio;

  @override
  State<WidgetImageCropEditor> createState() => _WidgetImageCropEditorState();
}

class _WidgetImageCropEditorState extends State<WidgetImageCropEditor> {
  Size? _sourceSize;
  double _zoom = 1;
  double _startZoom = 1;
  Offset _offset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  Size? _viewportSize;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  Future<void> _readSize() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (mounted)
        setState(
          () => _sourceSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
        );
      image.dispose();
    } finally {
      codec.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn vùng ảnh widget')),
    body: SafeArea(
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Kéo để đặt vùng ảnh, dùng hai ngón để phóng to. Ảnh gốc vẫn được giữ nguyên.',
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final source = _sourceSize;
                    if (source == null)
                      return const Center(child: CircularProgressIndicator());
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    _viewportSize = Size(width, height);
                    final base = math.max(
                      width / source.width,
                      height / source.height,
                    );
                    final drawnWidth = source.width * base * _zoom;
                    final drawnHeight = source.height * base * _zoom;
                    final maxX = (drawnWidth - width) / 2;
                    final maxY = (drawnHeight - height) / 2;
                    final x = _offset.dx.clamp(-maxX, maxX);
                    final y = _offset.dy.clamp(-maxY, maxY);
                    final left = (width - drawnWidth) / 2 + x;
                    final top = (height - drawnHeight) / 2 + y;
                    return GestureDetector(
                      onScaleStart: (details) {
                        _startZoom = _zoom;
                        _startOffset = Offset(x, y);
                        _startFocal = details.focalPoint;
                      },
                      onScaleUpdate: (details) => setState(() {
                        _zoom = (_startZoom * details.scale).clamp(1, 5);
                        _offset =
                            _startOffset + details.focalPoint - _startFocal;
                      }),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            const ColoredBox(color: Colors.black),
                            Positioned(
                              left: left,
                              top: top,
                              width: drawnWidth,
                              height: drawnHeight,
                              child: Image.memory(
                                widget.bytes,
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _sourceSize == null || _viewportSize == null
                  ? null
                  : () {
                      final width = _viewportSize!.width;
                      final height = _viewportSize!.height;
                      final source = _sourceSize!;
                      final base = math.max(
                        width / source.width,
                        height / source.height,
                      );
                      final drawnWidth = source.width * base * _zoom;
                      final drawnHeight = source.height * base * _zoom;
                      final x = _offset.dx.clamp(
                        -(drawnWidth - width) / 2,
                        (drawnWidth - width) / 2,
                      );
                      final y = _offset.dy.clamp(
                        -(drawnHeight - height) / 2,
                        (drawnHeight - height) / 2,
                      );
                      final left = (width - drawnWidth) / 2 + x;
                      final top = (height - drawnHeight) / 2 + y;
                      Navigator.pop(
                        context,
                        WidgetImageCrop(
                          left: (-left / drawnWidth).clamp(0, 1),
                          top: (-top / drawnHeight).clamp(0, 1),
                          right: ((width - left) / drawnWidth).clamp(0, 1),
                          bottom: ((height - top) / drawnHeight).clamp(0, 1),
                        ),
                      );
                    },
              child: const Text('Dùng vùng ảnh này'),
            ),
          ),
        ],
      ),
    ),
  );
}
