import 'package:flutter/material.dart';

import '../services/inventory_service.dart';
import '../widgets/inventory_item_card.dart';
import '../routes/app_routes.dart';
import '../models/item_model.dart';

class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final _service = InventoryService();


  Future<void> _goToAddItem() async {
    final result = await Navigator.pushNamed(context, AppRoutes.addItem);
    if (result is ItemModel) {
      _service.addItem(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Barang'),
      ),
      body: ValueListenableBuilder<List<ItemModel>>(
        valueListenable: _service.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const Center(
              child: Text('Belum ada data barang.'),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return InventoryItemCard(
                item: item,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}
