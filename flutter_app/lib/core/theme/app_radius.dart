import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const double xs   = 4;
  static const double sm   = 10;
  static const double md   = 14;
  static const double lg   = 18;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double full = 999;

  static const BorderRadius xsAll   = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll  = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));

  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
}

abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D281C10), blurRadius: 4,  spreadRadius: 0, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F281C10), blurRadius: 16, spreadRadius: 0, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x0F281C10), blurRadius: 8,  spreadRadius: 0, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x17281C10), blurRadius: 36, spreadRadius: 0, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x1A281C10), blurRadius: 40, spreadRadius: 0, offset: Offset(0, -4)),
  ];

  static const List<BoxShadow> primaryGlow = [
    BoxShadow(color: Color(0x40FF6A14), blurRadius: 20, spreadRadius: 0, offset: Offset(0, 4)),
  ];
}
