import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double x1  = 4;
  static const double x2  = 8;
  static const double x3  = 12;
  static const double x4  = 16;
  static const double x5  = 20;
  static const double x6  = 24;
  static const double x8  = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;

  static const double cardPadding = x4;
  static const double sectionGap  = x8;
  static const double itemGap     = x3;

  static double pagePaddingH(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return x10;
    if (w >= 600) return x6;
    return x4;
  }
}
