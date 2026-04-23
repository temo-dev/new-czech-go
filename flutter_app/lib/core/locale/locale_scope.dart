import 'package:flutter/widgets.dart';

import 'locale_provider.dart';

class LocaleScope extends InheritedNotifier<LocaleProvider> {
  const LocaleScope({
    super.key,
    required LocaleProvider super.notifier,
    required super.child,
  });

  static LocaleProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope missing above widget tree');
    return scope!.notifier!;
  }
}
