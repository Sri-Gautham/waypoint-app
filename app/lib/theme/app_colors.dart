import 'package:flutter/material.dart';

/// The "Clean & Modern Minimal" palette from the Waypoint design canvas —
/// now a [ThemeExtension] so it can swap between [light] and [dark] with
/// the rest of [ThemeData], instead of being fixed `static const` values.
/// Access via `context.colors.xxx` (see the [AppColorsContext] extension
/// at the bottom) rather than a static `AppColors.xxx` reference.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.placeholder,
    required this.border,
    required this.divider,
    required this.accent,
    required this.accentDark,
    required this.accentTint,
    required this.success,
    required this.successBg,
    required this.pendingBg,
    required this.moneyOwe,
    required this.moneyOwed,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color placeholder;
  final Color border;
  final Color divider;
  final Color accent;
  final Color accentDark;
  final Color accentTint;
  final Color success;
  final Color successBg;
  final Color pendingBg;
  final Color moneyOwe;
  final Color moneyOwed;

  static const light = AppColors(
    background: Color(0xFFFBFCFD),
    surface: Colors.white,
    textPrimary: Color(0xFF101214),
    textSecondary: Color(0xFF616366),
    textTertiary: Color(0xFF6F7274),
    placeholder: Color(0xFF9D9EA0),
    border: Color(0xFFD6D8D9),
    divider: Color(0xFFEFF1F2),
    accent: Color(0xFF2151A1),
    accentDark: Color(0xFF023481),
    accentTint: Color(0xFFEDEFF0),
    success: Color(0xFF085023),
    successBg: Color(0xFFBAF6C5),
    pendingBg: Color(0xFFE5E8EB),
    moneyOwe: Color(0xFFA8372A),
    moneyOwed: Color(0xFF085023),
  );

  static const dark = AppColors(
    background: Color(0xFF0B0E13),
    surface: Color(0xFF171C24),
    textPrimary: Color(0xFFF1F3F5),
    textSecondary: Color(0xFFA8AEB6),
    textTertiary: Color(0xFF7D838C),
    placeholder: Color(0xFF6B7178),
    border: Color(0xFF2C323C),
    divider: Color(0xFF1E232C),
    accent: Color(0xFF6D95D6),
    accentDark: Color(0xFF9BB8E8),
    accentTint: Color(0xFF1B2431),
    success: Color(0xFF6FDB98),
    successBg: Color(0xFF16321F),
    pendingBg: Color(0xFF262C35),
    moneyOwe: Color(0xFFE8897A),
    moneyOwed: Color(0xFF6FDB98),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? placeholder,
    Color? border,
    Color? divider,
    Color? accent,
    Color? accentDark,
    Color? accentTint,
    Color? success,
    Color? successBg,
    Color? pendingBg,
    Color? moneyOwe,
    Color? moneyOwed,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      placeholder: placeholder ?? this.placeholder,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      accentTint: accentTint ?? this.accentTint,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      pendingBg: pendingBg ?? this.pendingBg,
      moneyOwe: moneyOwe ?? this.moneyOwe,
      moneyOwed: moneyOwed ?? this.moneyOwed,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      pendingBg: Color.lerp(pendingBg, other.pendingBg, t)!,
      moneyOwe: Color.lerp(moneyOwe, other.moneyOwe, t)!,
      moneyOwed: Color.lerp(moneyOwed, other.moneyOwed, t)!,
    );
  }
}

/// `context.colors.textPrimary` instead of a static `AppColors.textPrimary`
/// reference — resolves to whichever of [AppColors.light]/[AppColors.dark]
/// is active for the current theme.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
