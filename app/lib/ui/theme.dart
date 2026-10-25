// Colours, type and spacing from the ZapWise design chart v0.1.
// Pixel art draws objects; soft UI (raised cards, inset wells) holds content.
// Light comes from the top left for both.
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

class ZC {
  static const milk = Color(0xFFFDE9E7); // app ground, soft surfaces
  static const shade = Color(0xFFE9C3C2); // soft shadow, bottom right
  static const glow = Color(0xFFFFFFFF); // soft highlight, top left
  static const cocoa = Color(0xFF4B2E39); // text, pixel outline
  static const cocoa2 = Color(0xFF8A5F6C); // secondary text
  static const rose = Color(0xFFE0607A); // brand graphics only, not text
  static const roseDeep = Color(0xFFB23A57); // links, selected labels
  static const straw = Color(0xFFF59BAA); // pixel button fill
  static const strawShade = Color(0xFFE27C8F);
  static const blush = Color(0xFFFBC9CF);
  static const butter = Color(0xFFFFE3A3);
  static const mint = Color(0xFFA8DCC6);
  static const mintDeep = Color(0xFF2E6E58);
  static const peach = Color(0xFFFFC4A3);
  static const sky = Color(0xFFC6E6F3);
  static const paper = Color(0xFFFFFFFF);
  static const disabledFill = Color(0xFFEED9DB);
  static const disabledText = Color(0xFF8E7480);
  static const disabledEdge = Color(0xFFB79AA3);
  static const dim = Color(0x944B2E39); // 58 % cocoa scrim
  static const viewfinder = Color(0xFF2F1F27);
  // 0.5: rows and choices are split by lines instead of sitting in cards
  static const line = Color(0xFFEDCDCD);
  static const lineStrong = Color(0xFFD8A7AD);
  static const peachSoft = Color(0xFFFFE3D3);
  static const pressTint = Color(0x59FBC9CF); // blush at 35 %, while a row is held down
}

class ZFont {
  static const display = 'PixelifySans';
  static const body = 'Nunito';
}

/// Type scale from the design chart (sizes in logical pixels).
class ZT {
  // numbers and times use Nunito: the pixel face is hard to read for low-vision users
  static const bigNumber = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w900, fontSize: 40, height: 1.1, color: ZC.cocoa, fontFeatures: [FontFeature.tabularFigures()]);
  static const title = TextStyle(fontFamily: ZFont.display, fontWeight: FontWeight.w600, fontSize: 22, height: 1.2, color: ZC.cocoa);
  // the pixel face is kept for screen, tab and sheet titles; headings and buttons use Nunito so 1 and 7 read apart
  static const h2 = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 18, height: 1.25, color: ZC.cocoa);
  static const h3 = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 16, height: 1.3, color: ZC.cocoa);
  static const button = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 16, height: 1.25, color: ZC.cocoa);
  static const cta = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w900, fontSize: 18, height: 1.15, color: ZC.cocoa);
  static const body = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w600, fontSize: 15, height: 1.45, color: ZC.cocoa);
  static const bodyBold = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 15, height: 1.4, color: ZC.cocoa);
  static const small = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w700, fontSize: 13, height: 1.4, color: ZC.cocoa);
  static const smallMuted = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w700, fontSize: 13, height: 1.4, color: ZC.cocoa2);
  static const foot = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.45, color: ZC.cocoa2);
  static const link = TextStyle(
      fontFamily: ZFont.body,
      fontWeight: FontWeight.w800,
      fontSize: 14,
      height: 1.3,
      color: ZC.roseDeep,
      decoration: TextDecoration.underline,
      decorationColor: ZC.roseDeep);
  static const tab = TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 12, height: 1.0, color: ZC.cocoa2);
}

class ZS {
  static const side = 16.0; // screen side padding
  static const gap = 14.0; // between blocks
  static const cardRadius = 22.0;
  static const wellRadius = 18.0;
  static const buttonRadius = 16.0;
  static const pixelRadius = 6.0;
  static const minTouch = 44.0;
}

ThemeData zapTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: ZFont.body,
    colorScheme: ColorScheme.fromSeed(seedColor: ZC.straw, brightness: Brightness.light).copyWith(
      primary: ZC.roseDeep,
      onPrimary: ZC.paper,
      surface: ZC.milk,
      onSurface: ZC.cocoa,
    ),
    scaffoldBackgroundColor: ZC.milk,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ZC.cocoa, displayColor: ZC.cocoa, fontFamily: ZFont.body),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: ZC.roseDeep, selectionHandleColor: ZC.roseDeep),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ZC.cocoa,
      contentTextStyle: TextStyle(fontFamily: ZFont.body, fontWeight: FontWeight.w800, fontSize: 14, color: ZC.paper),
      behavior: SnackBarBehavior.floating,
      shape: StadiumBorder(),
    ),
  );
}
