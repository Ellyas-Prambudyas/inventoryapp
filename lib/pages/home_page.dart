import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../widgets/primary_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat datang di Inventory App',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola stok barang dengan mudah dan rapi.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Lihat Daftar Barang',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.inventoryList);
              },
            ),
          ],
        ),
      ),
    );
  }
}
