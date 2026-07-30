import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens (agriconnect-theme.md § Brand): not specified per-brightness
/// in agriconnect-theme-dark.md, so they carry over unchanged in dark mode.
const _primary = Color(0xFF228B22);
const _onPrimary = Color(0xFFFFFFFF);
const _primaryContainer = Color(0xFF228B22);
const _onPrimaryContainer = Color(0xFF1A2E1A);

const _secondary = Color(0xFFD2B48C);
const _onSecondary = Color(0xFFFFFFFF);
const _secondaryContainer = Color(0xFFD2B48C);
const _onSecondaryContainer = Color(0xFF1A2E1A);

const _accent = Color(0xFFC8E6C9);
const _onAccent = Color(0xFF1A2E1A);
const _accentContainer = Color(0xFFC8E6C9);
const _onAccentContainer = Color(0xFF1A2E1A);

/// Surfaces & Content — agriconnect-theme.md (light) / agriconnect-theme-dark.md.
const _lightBackground = Color(0xFFF4F7F2);
const _lightSurface = Color(0xFFFFFFFF);
const _lightOnSurface = Color(0xFF1A2E1A);
const _lightSurfaceVariant = Color(0xFFF0F4EF);
const _lightOnSurfaceVariant = Color(0xFF5D6B5D);
const _lightOutline = Color(0xFFD1DED1);
const _lightDivider = Color(0xFFE2E8E2);

const _darkBackground = Color(0xFF0D140D);
const _darkSurface = Color(0xFF1E261E);
const _darkOnSurface = Color(0xFFF1F8F1);
const _darkSurfaceVariant = Color(0xFF2A332A);
const _darkOnSurfaceVariant = Color(0xFFB0BCB0);
const _darkOutline = Color(0xFF3D473D);
const _darkDivider = Color(0xFF2D362D);

/// Status colors (§ Status Colors in both theme docs): semantic states that
/// don't map to a Material ColorScheme role, split light/dark since dark
/// mode uses softened hues (and Warning flips to black-on-yellow) rather
/// than a straight reuse of the light values. `error`/`onError` live here
/// too and feed the ColorSchemes below, since both docs treat Error as a
/// status color rather than a distinct brand token.
class AgriStatusColors {
  const AgriStatusColors._();

  static const successLight = Color(0xFF2E7D32);
  static const onSuccessLight = Color(0xFFFFFFFF);
  static const warningLight = Color(0xFFF9A825);
  static const onWarningLight = Color(0xFFFFFFFF);
  static const errorLight = Color(0xFFC62828);
  static const onErrorLight = Color(0xFFFFFFFF);
  static const infoLight = Color(0xFF0277BD);
  static const onInfoLight = Color(0xFFFFFFFF);

  static const successDark = Color(0xFF81C784);
  static const onSuccessDark = Color(0xFFFFFFFF);
  static const warningDark = Color(0xFFFFD54F);
  static const onWarningDark = Color(0xFF000000);
  static const errorDark = Color(0xFFE57373);
  static const onErrorDark = Color(0xFFFFFFFF);
  static const infoDark = Color(0xFF4FC3F7);
  static const onInfoDark = Color(0xFFFFFFFF);

  static Color success(Brightness brightness) =>
      brightness == Brightness.dark ? successDark : successLight;
  static Color onSuccess(Brightness brightness) =>
      brightness == Brightness.dark ? onSuccessDark : onSuccessLight;
  static Color warning(Brightness brightness) =>
      brightness == Brightness.dark ? warningDark : warningLight;
  static Color onWarning(Brightness brightness) =>
      brightness == Brightness.dark ? onWarningDark : onWarningLight;
  static Color error(Brightness brightness) =>
      brightness == Brightness.dark ? errorDark : errorLight;
  static Color onError(Brightness brightness) =>
      brightness == Brightness.dark ? onErrorDark : onErrorLight;
  static Color info(Brightness brightness) =>
      brightness == Brightness.dark ? infoDark : infoLight;
  static Color onInfo(Brightness brightness) =>
      brightness == Brightness.dark ? onInfoDark : onInfoLight;
}

final lightColorScheme = ColorScheme.fromSeed(
  seedColor: _primary,
  brightness: Brightness.light,
  primary: _primary,
  onPrimary: _onPrimary,
  primaryContainer: _primaryContainer,
  onPrimaryContainer: _onPrimaryContainer,
  secondary: _secondary,
  onSecondary: _onSecondary,
  secondaryContainer: _secondaryContainer,
  onSecondaryContainer: _onSecondaryContainer,
  tertiary: _accent,
  onTertiary: _onAccent,
  tertiaryContainer: _accentContainer,
  onTertiaryContainer: _onAccentContainer,
  error: AgriStatusColors.errorLight,
  onError: AgriStatusColors.onErrorLight,
  surface: _lightSurface,
  onSurface: _lightOnSurface,
  surfaceContainerHighest: _lightSurfaceVariant,
  onSurfaceVariant: _lightOnSurfaceVariant,
  outline: _lightOutline,
  outlineVariant: _lightDivider,
);

final darkColorScheme = ColorScheme.fromSeed(
  seedColor: _primary,
  brightness: Brightness.dark,
  primary: _primary,
  onPrimary: _onPrimary,
  primaryContainer: _primaryContainer,
  onPrimaryContainer: _onPrimaryContainer,
  secondary: _secondary,
  onSecondary: _onSecondary,
  secondaryContainer: _secondaryContainer,
  onSecondaryContainer: _onSecondaryContainer,
  tertiary: _accent,
  onTertiary: _onAccent,
  tertiaryContainer: _accentContainer,
  onTertiaryContainer: _onAccentContainer,
  error: AgriStatusColors.errorDark,
  onError: AgriStatusColors.onErrorDark,
  surface: _darkSurface,
  onSurface: _darkOnSurface,
  surfaceContainerHighest: _darkSurfaceVariant,
  onSurfaceVariant: _darkOnSurfaceVariant,
  outline: _darkOutline,
  outlineVariant: _darkDivider,
);

TextTheme _interTextTheme(TextTheme base) {
  return GoogleFonts.interTextTheme(base).copyWith(
    bodyLarge: GoogleFonts.inter(textStyle: base.bodyLarge, fontSize: 16),
  );
}

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: lightColorScheme,
  scaffoldBackgroundColor: _lightBackground,
  textTheme: _interTextTheme(ThemeData.light().textTheme),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: darkColorScheme,
  scaffoldBackgroundColor: _darkBackground,
  textTheme: _interTextTheme(ThemeData.dark().textTheme),
);
