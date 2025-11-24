import 'package:flutter/material.dart';

// Warna yang diambil dari AddItemPage
const Color kPrimary = Color(0xFFF28B3A); 

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primaryColor: kPrimary,
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.orange,
    ).copyWith(
      secondary: kPrimary,
    ),
    appBarTheme: const AppBarTheme(
      color: kPrimary,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    scaffoldBackgroundColor: const Color(0xFFFFF3A3), // kBackground
    fontFamily: 'Inter',
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
