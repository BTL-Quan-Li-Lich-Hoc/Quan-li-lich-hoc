import 'package:flutter/material.dart';

import 'tien_mon_premium_contract.dart';

abstract final class TienMonSafeText {
  static const Set<String> guardedGlyphs = <String>{'•', '·', '–', '—'};

  static List<TextSpan> spans(String text, {TextStyle? style}) {
    final result = <TextSpan>[];
    final buffer = StringBuffer();

    void flushPrimary() {
      if (buffer.isEmpty) return;
      result.add(
        TextSpan(
          text: buffer.toString(),
          style:
              style?.copyWith(fontFamily: TienMonPremiumContract.fontFamily) ??
              const TextStyle(fontFamily: TienMonPremiumContract.fontFamily),
        ),
      );
      buffer.clear();
    }

    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      if (guardedGlyphs.contains(character)) {
        flushPrimary();
        result.add(
          TextSpan(
            text: character,
            style:
                style?.copyWith(fontFamily: 'Roboto') ??
                const TextStyle(fontFamily: 'Roboto'),
          ),
        );
      } else {
        buffer.write(character);
      }
    }
    flushPrimary();
    return result;
  }
}

class TienMonText extends StatelessWidget {
  const TienMonText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(children: TienMonSafeText.spans(text, style: style)),
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
  );
}
