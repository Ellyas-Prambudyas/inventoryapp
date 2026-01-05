import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'routes/app_routes.dart';

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Jika sudah login (session masih ada), langsung masuk dashboard.
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Inventory App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: session == null ? AppRoutes.login : AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
