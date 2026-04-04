import 'package:flutter/services.dart';

/// Centralised haptic feedback — keeps haptic calls consistent and easy to tune.
abstract class HapticUtils {

  /// Light tap — selection, toggles, minor UI acknowledgements.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium impact — card taps, confirm buttons.
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Heavy thud — policy activation, major CTAs, disruption alerts.
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Success pattern: light → pause → heavy. Used for activation confirmation.
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  /// Error pattern: rapid double heavy. Used for fraud flags, failures.
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.heavyImpact();
  }

  /// Subtle tick — used for the sliding swipe-to-activate widget.
  static Future<void> tick() => HapticFeedback.selectionClick();
}