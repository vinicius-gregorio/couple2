import 'package:flutter/material.dart';

/// Bundled Plus Jakarta Sans. Every text style names this family so the web
/// engine does not fall back to Roboto on fonts.gstatic.com.
const String kAppFontFamily = 'PlusJakartaSans';

const List<String> kAppFontFallbacks = <String>[kAppFontFamily];

TextStyle appTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallbacks,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}
