import 'package:flutter/material.dart';

class AppColors {
  static const sidebar = Color(0xFF16203B);
  static const sidebarText = Colors.white;
  static const sidebarSelected = Colors.white;
  static const sidebarSection = Color(0xFF8B95A8);
  static const accent = Color(0xFFF9B93B);
  static const background = Color(0xFFF6F7F9);
  static const cardBackground = Colors.white;
  static const available = Color(0xFF4CAF50);
  static const unavailable = Color(0xFFE53935);

  // ===== Design-system palette (ClickEat Admin) =====
  static const navy = Color(0xFF16203B);
  static const navy700 = Color(0xFF1E2A4A);
  static const gold = Color(0xFFF5B82E);
  static const green = Color(0xFF22C55E);
  static const greenInk = Color(0xFF15803D);
  static const amber = Color(0xFFF59E0B);
  static const amberInk = Color(0xFFB45309);
  static const red = Color(0xFFEF4444);
  static const redInk = Color(0xFFB91C1C);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF8FAFC);
  static const line = Color(0xFFE8ECF1);
  static const ink = Color(0xFF16203B);
  static const ink2 = Color(0xFF5A6478);
  static const ink3 = Color(0xFF8A94A6);
  static const ink4 = Color(0xFFAEB6C4);
}

class _InstantTransitionBuilder extends PageTransitionsBuilder {
  const _InstantTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

ThemeData buildTheme() {
  const noTransition = _InstantTransitionBuilder();
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    // Seed from navy so Material defaults (dropdowns, focus, splashes) stop
    // rendering in the default M3 purple.
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: noTransition},
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
  );
}
