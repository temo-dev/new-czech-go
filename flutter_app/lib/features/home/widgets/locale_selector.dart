import 'package:flutter/material.dart';

import '../../../core/locale/locale_scope.dart';
import '../../../core/locale/supported_locales.dart';

class LocaleSelector extends StatelessWidget {
  const LocaleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = LocaleScope.of(context);
    final tooltip = provider.code == AppLocale.en ? 'Language' : 'Ngôn ngữ';
    return PopupMenuButton<String>(
      tooltip: tooltip,
      icon: const Icon(Icons.language),
      initialValue: provider.code,
      onSelected: provider.setLocale,
      itemBuilder: (context) => [
        for (final code in AppLocale.all)
          PopupMenuItem<String>(
            value: code,
            child: Row(
              children: [
                if (provider.code == code)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(AppLocale.label(code)),
              ],
            ),
          ),
      ],
    );
  }
}
