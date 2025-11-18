import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../pages/home_page.dart';
import '../pages/inventory_list_page.dart';
import '../pages/add_item_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String inventoryList = '/inventory-list';
  static const String addItem = '/add-item';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case inventoryList:
        return MaterialPageRoute(builder: (_) => const InventoryListPage());
      case addItem:
        return MaterialPageRoute(builder: (_) => const AddItemPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
