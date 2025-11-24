import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../pages/home_page.dart';
import '../pages/inventory_list_page.dart';
import '../pages/add_item_page.dart';
import '../pages/service_item_page.dart';
import '../pages/scan_qr_page.dart';

class AppRoutes {
  // ===================== NAMA ROUTE =====================
  static const String login = '/login';
  static const String home = '/home';

  static const String inventoryList = '/inventory-list';
  static const String addItem = '/add-item';
  static const String addService = '/add-service';

  static const String scanQr = '/scan-qr';

  // ===================== GENERATE ROUTE =====================
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      case inventoryList:
        return MaterialPageRoute(
          builder: (_) => const InventoryListPage(),
          settings: settings,
        );
      case addItem:
        return MaterialPageRoute(
          builder: (_) => const AddItemPage(),
          settings: settings,
        );
      case addService:
        return MaterialPageRoute(
          builder: (_) => const AddServicePage(),
          settings: settings,
        );
      case scanQr:
        return MaterialPageRoute(
          builder: (_) => const ScanQrPage(),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
          settings: settings,
        );
    }
  }
}
