import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return IconButton(
      icon: Icon(
        isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
        color: isDarkMode ? Colors.amber : Colors.indigo,
      ),
      onPressed: () {
        ref.read(themeNotifierProvider.notifier).toggleTheme(!isDarkMode);
      },
      tooltip: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
    );
  }
}
