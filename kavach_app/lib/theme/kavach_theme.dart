import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';

class KavachTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: K.bg,
        primaryColor: K.primary,
        colorScheme: const ColorScheme.dark(
          primary: K.primary,
          secondary: K.accent,
          surface: K.surface,
          error: K.danger,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: K.textPrimary,
        ),
        textTheme: GoogleFonts.nunitoSansTextTheme().copyWith(
          displayLarge: GoogleFonts.rajdhani(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: K.textPrimary,
            letterSpacing: 1,
          ),
          displayMedium: GoogleFonts.rajdhani(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: K.textPrimary,
          ),
          headlineLarge: GoogleFonts.rajdhani(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: K.textPrimary,
          ),
          headlineMedium: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: K.textPrimary,
          ),
          bodyLarge: GoogleFonts.nunitoSans(
            fontSize: 15,
            color: K.textPrimary,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.nunitoSans(
            fontSize: 13,
            color: K.textSecondary,
            height: 1.5,
          ),
          labelSmall: GoogleFonts.dmMono(
            fontSize: 12,
            color: K.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: K.bg,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: GoogleFonts.rajdhani(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: K.textPrimary,
          ),
          iconTheme: const IconThemeData(color: K.textSecondary),
        ),
        cardTheme: CardThemeData(
          color: K.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: K.border, width: 1),
          ),
          margin: const EdgeInsets.only(bottom: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: K.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: K.accent,
            side: const BorderSide(color: K.accent, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: K.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: K.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: K.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: K.primary, width: 2),
          ),
          hintStyle: GoogleFonts.nunitoSans(fontSize: 13, color: K.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dividerTheme: const DividerThemeData(color: K.border, thickness: 1, space: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: K.surface,
          selectedItemColor: K.accent,
          unselectedItemColor: K.textMuted,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: K.surface2,
          labelStyle: GoogleFonts.dmMono(fontSize: 11, color: K.textSecondary),
          side: const BorderSide(color: K.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
      );
}
