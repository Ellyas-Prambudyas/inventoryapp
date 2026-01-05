import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase (URL & anonKey harus benar)
  await Supabase.initialize(
    url: 'https://rworliddhofsvbpimvaj.supabase.co',
    anonKey: 'sb_publishable_k6qNM0C82cfOf6jXmh96UQ_XRSY4fet',
  );

  runApp(const InventoryApp());
}
