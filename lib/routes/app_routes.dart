import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/home_page.dart';
import '../pages/inventory_list_page.dart';
import '../pages/add_item_page.dart';
import '../pages/service_item_page.dart';
import '../pages/scan_qr_page.dart';

// =========== HALAMAN BARU ===========
import '../pages/notification_page.dart';
import '../pages/settings_page.dart';
import '../pages/profile_page.dart';
import '../pages/stock_out_history_page.dart'; // Riwayat Data Keluar

class AppRoutes {
  // ===================== NAMA ROUTE =====================
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';

  static const String inventoryList = '/inventory-list';
  static const String addItem = '/add-item';
  static const String addService = '/add-service';

  static const String scanQr = '/scan-qr';

  // ===================== PROFIL & PENGATURAN =====================
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile'; // alias edit profil
  static const String settings = '/settings';

  // ===================== RIWAYAT DATA KELUAR =====================
  static const String stockOutHistory = '/stock-out-history';

  // ===================== GENERATE ROUTE =====================
  static Route<dynamic> onGenerateRoute(RouteSettings settingsRoute) {
    switch (settingsRoute.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settingsRoute,
        );

      case register:
        return MaterialPageRoute(
          builder: (_) => const RegisterPage(),
          settings: settingsRoute,
        );

      case home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settingsRoute,
        );

      case inventoryList:
        return MaterialPageRoute(
          builder: (_) => const InventoryListPage(),
          settings: settingsRoute,
        );

      case addItem:
        return MaterialPageRoute(
          builder: (_) => const AddItemPage(),
          settings: settingsRoute,
        );

      case addService:
        return MaterialPageRoute(
          // di service_item_page.dart class-nya AddServicePage
          builder: (_) => const AddServicePage(),
          settings: settingsRoute,
        );

      case scanQr:
        return MaterialPageRoute(
          builder: (_) => const ScanQrPage(),
          settings: settingsRoute,
        );

      // ========= ROUTE BARU =========
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationPage(),
          settings: settingsRoute,
        );

      case profile:
        return MaterialPageRoute(
          builder: (_) => const ProfilePage(),
          settings: settingsRoute,
        );

      // editProfile sementara diarahkan ke halaman yang sama
      case editProfile:
        return MaterialPageRoute(
          builder: (_) => const ProfilePage(),
          settings: settingsRoute,
        );

      case settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settingsRoute,
        );

      case stockOutHistory:
        return MaterialPageRoute(
          builder: (_) => const StockOutHistoryPage(),
          settings: settingsRoute,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settingsRoute,
        );
    }
  }
}
