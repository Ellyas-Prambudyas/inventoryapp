import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase (URL & anonKey harus benar)
  await Supabase.initialize(
    url: '',
    anonKey: '',
  );

  runApp(const InventoryApp());
}
