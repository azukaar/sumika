import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A standardized interaction indicator for cards that can be expanded via hold/long press.
/// 
/// This component provides:
/// - Consistent visual indication across all card types
/// - Universal tooltip that works on both mobile and desktop
/// - Platform-appropriate messaging
/// - Consistent styling and positioning
class CardInteractionIndicator extends StatefulWidget {
  final String? customTooltip;
  final Color? iconColor;
  final double iconSize;
  final EdgeInsets padding;

  const CardInteractionIndicator({
    super.key,
    this.customTooltip,
    this.iconColor,
    this.iconSize = 16,
    this.padding = const EdgeInsets.all(4),
  });

  @override
  State<CardInteractionIndicator> createState() => _CardInteractionIndicatorState();
}

class _CardInteractionIndicatorState extends State<CardInteractionIndicator> {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    // Platform-appropriate tooltip message
    final tooltipMessage = widget.customTooltip ?? _getDefaultTooltipMessage();
    final isMobile = !kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS);
    
    final iconWidget = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.touch_app_rounded, // Universal "touch/interact" icon
        size: widget.iconSize,
        color: widget.iconColor ?? 
              Theme.of(context).colorScheme.primary.withOpacity(0.7),
      ),
    );

    if (isMobile) {
      // On mobile, show tooltip on tap for better UX
      return GestureDetector(
        onTap: () {
          _tooltipKey.currentState?.ensureTooltipVisible();
        },
        child: Tooltip(
          key: _tooltipKey,
          message: tooltipMessage,
          preferBelow: false,
          waitDuration: Duration.zero, // Show immediately when triggered
          child: iconWidget,
        ),
      );
    } else {
      // On desktop, use default tooltip behavior (hover)
      return Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 500),
        child: iconWidget,
      );
    }
  }

  String _getDefaultTooltipMessage() {
    // Provide platform-appropriate messaging
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return 'Right-click or hold to expand';
    } else {
      return 'Hold to expand';
    }
  }
}

/// Extension widget that wraps any card with standardized interaction behavior
/// 
/// Usage:
/// ```dart
/// InteractiveCard(
///   onExpand: () => showModal(),
///   child: MyCardContent(),
/// )
/// ```
class InteractiveCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onExpand;
  final String? tooltip;
  final bool showIndicator;

  const InteractiveCard({
    super.key,
    required this.child,
    required this.onExpand,
    this.tooltip,
    this.showIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? (kIsWeb || defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux
          ? 'Right-click or hold to expand'
          : 'Hold to expand'),
      child: GestureDetector(
        onSecondaryTap: onExpand, // Right click
        onLongPress: onExpand,    // Long press
        child: child,
      ),
    );
  }
}