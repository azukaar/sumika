import 'package:flutter/material.dart';
import '../app_mode.dart';

class SettingsIconButton extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const SettingsIconButton({
    super.key,
    this.margin = const EdgeInsets.only(right: 16),
  });

  @override
  Widget build(BuildContext context) {
    if (AppMode.noConfig) return const SizedBox.shrink();

    return Container(
      margin: margin,
      child: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.settings_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pushNamed(context, '/settings'),
      ),
    );
  }
}
