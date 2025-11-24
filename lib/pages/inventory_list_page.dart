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

