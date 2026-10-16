import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow-the-system, remembered on the device.
class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;

  Future<void> init() async {
    final saved = (await SharedPreferences.getInstance()).getString('theme');
    mode = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('theme', m.name);
  }
}

/// Brand colours (the same tokens as the web app's design v3): calm evergreen on soft neutral greens.
class Brand {
  static const accent = Color(0xFF14594A); // Forest
  static const accentDark = Color(0xFF8FDCB8); // Mint (accent on dark)
  static const hero = Color(0xFF0C3A31); // Deep forest
  static const heroDeep = Color(0xFF08271F);
  static const heroDark = Color(0xFF0E2A23);
  static const heroLight = Color(0xFF1B7A63);
  static const spark = Color(
    0xFFEE7F43,
  ); // Apricot: the few people you chose, likes, new things
  static const sparkLight = Color(0xFFFF9A62);
}

/// Serif face for reading (posts, comments, quotes) — the same Noto Serif the web app uses.
const readFont = 'NotoSerif';
const uiFont = 'Inter';

class AppTheme {
  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: Brand.accent,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDDF0E7),
      onPrimaryContainer: Color(0xFF083027),
      secondary: Color(0xFF4A635A),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD9EBE2),
      onSecondaryContainer: Color(0xFF16302A),
      tertiary: Brand.spark,
      onTertiary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1A1F1C),
      onSurfaceVariant: Color(0xFF646D66),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFAF8F3),
      surfaceContainer: Color(0xFFF6F3EC),
      surfaceContainerHigh: Color(0xFFF1EDE4),
      surfaceContainerHighest: Color(0xFFEFEBE2),
      outline: Color(0xFF8A938E),
      outlineVariant: Color(0xFFE4DFD3),
      shadow: Color(0xFF142019),
      inverseSurface: Color(0xFF2B312E),
      onInverseSurface: Color(0xFFF1F3F0),
    ),
    const Color(0xFFF6F3EC),
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Brand.accentDark,
      onPrimary: Color(0xFF07130E),
      primaryContainer: Color(0xFF1A2D26),
      onPrimaryContainer: Color(0xFFCDEFE0),
      secondary: Color(0xFF9DB8AD),
      onSecondary: Color(0xFF0E1A15),
      secondaryContainer: Color(0xFF26352F),
      onSecondaryContainer: Color(0xFFD3E8DE),
      tertiary: Brand.sparkLight,
      onTertiary: Color(0xFF2A1405),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF3B0907),
      surface: Color(0xFF141B18),
      onSurface: Color(0xFFEAEFEB),
      onSurfaceVariant: Color(0xFF9AA79F),
      surfaceContainerLowest: Color(0xFF0A0F0D),
      surfaceContainerLow: Color(0xFF101614),
      surfaceContainer: Color(0xFF161D1A),
      surfaceContainerHigh: Color(0xFF1B2420),
      surfaceContainerHighest: Color(0xFF232D28),
      outline: Color(0xFF6B756F),
      outlineVariant: Color(0xFF27312C),
      shadow: Colors.black,
      inverseSurface: Color(0xFFE8ECE9),
      onInverseSurface: Color(0xFF191C1A),
    ),
    const Color(0xFF0D1311),
  );

  static ThemeData _build(ColorScheme cs, Color bg) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      fontFamily: uiFont,
    );
    final text = base.textTheme
        .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface)
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.25,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.25,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.3,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        );
    final stadium = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );
    return base.copyWith(
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: cs.error),
        ),
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: stadium,
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: stadium,
          side: BorderSide(color: cs.outlineVariant),
          foregroundColor: cs.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: stadium,
          foregroundColor: cs.primary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        side: BorderSide.none,
        shape: stadium,
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          side: BorderSide(color: cs.outlineVariant),
          selectedBackgroundColor: cs.primaryContainer,
          selectedForegroundColor: cs.onPrimaryContainer,
          visualDensity: VisualDensity.comfortable,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : cs.outline,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.primaryContainer,
      ),
    );
  }
}
