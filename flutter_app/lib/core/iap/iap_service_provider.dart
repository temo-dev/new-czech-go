import 'package:flutter/material.dart';

import 'iap_service.dart';

/// InheritedWidget that hands the live [IAPService] down the tree so
/// the paywall + upgrade-prompt dialog can reach it without prop
/// drilling. Mirrors [AuthServiceProvider] so the wiring story stays
/// uniform across V17 deps.
class IAPServiceProvider extends InheritedWidget {
  const IAPServiceProvider({
    super.key,
    required this.service,
    required super.child,
  });

  final IAPService service;

  static IAPService of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<IAPServiceProvider>();
    assert(provider != null, 'IAPServiceProvider missing in widget tree');
    return provider!.service;
  }

  /// Lookup variant that returns null instead of asserting. Useful for
  /// transitional code paths that may run before the provider is wired.
  static IAPService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IAPServiceProvider>()?.service;

  @override
  bool updateShouldNotify(covariant IAPServiceProvider oldWidget) =>
      service != oldWidget.service;
}
