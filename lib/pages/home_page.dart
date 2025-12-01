import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../routes/app_routes.dart';
import '../services/inventory_service.dart';
import '../services/service_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _itemService = InventoryService(); // barang baru -> tabel items
  final _serviceService = ServiceService(); // item service -> tabel services

  String _searchQuery = '';
  bool _showServices = false; // false = Barang Baru, true = Item Service

  @override
  void initState() {
    super.initState();
    _itemService.loadItems();
    _serviceService.loadServices();
  }

  // --------- Buka halaman Scan QR ----------
  void _onScanQrTap() {
    Navigator.pushNamed(context, AppRoutes.scanQr);
  }
  // -----------------------------------------

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F5F5);
    const orange = Color(0xFFFF7A00);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= HEADER =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Halo, Ellyas',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Gudang Utama',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _SquareIconButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notifikasi ditekan'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ================= SEARCH BAR =================
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search, color: Colors.grey),
                    hintText: 'Cari barang...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.black87),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),

              // ================= STAT CARDS =================
              ValueListenableBuilder<List<ItemModel>>(
                valueListenable: _itemService.items,
                builder: (context, items, _) {
                  return ValueListenableBuilder<List<ItemModel>>(
                    valueListenable: _serviceService.services,
                    builder: (context, services, __) {
                      final totalItems = items.length + services.length;
                      final totalServices = services.length;

                      return Row(
                        children: [
                          // --- Total Stok ---
                          Expanded(
                            child: _StatCard(
                              label: 'Total Stok',
                              value: totalItems.toString(),
                              color: const Color(0xFF007BFF),
                              icon: Icons.inventory_2_rounded,
                              selected: !_showServices,
                              onTap: () {
                                setState(() {
                                  _showServices = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // --- Perbaikan (Item Service) ---
                          Expanded(
                            child: _StatCard(
                              label: 'Perbaikan',
                              value: totalServices.toString(),
                              color: const Color(0xFFEEEEEE),
                              icon: Icons.build_circle_rounded,
                              selected: _showServices,
                              onTap: () {
                                setState(() {
                                  _showServices = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // --- Data Keluar (dummy 0) ---
                          const Expanded(
                            child: _StatCard(
                              label: 'Data Keluar',
                              value: '0',
                              color: Color(0xFFFF3B30),
                              icon: Icons.exit_to_app_rounded,
                              selected: false,
                              onTap: null,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),

              // ================= TITLE DAFTAR BARANG =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daftar Barang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.filter_list_rounded,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Filter belum diimplementasikan :)'),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // ================= LIST BARANG / SERVICE =================
              Expanded(
                child: ValueListenableBuilder<List<ItemModel>>(
                  valueListenable:
                      _showServices ? _serviceService.services : _itemService.items,
                  builder: (context, items, _) {
                    final filtered = items.where((item) {
                      if (_searchQuery.isEmpty) return true;
                      return item.name.toLowerCase().contains(_searchQuery) ||
                          item.category.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _showServices
                              ? 'Belum ada data item service.'
                              : 'Belum ada data barang baru.',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _InventoryListCard(
                          item: item,
                          imageUrl: item.imageUrl,
                          isService: _showServices,
                          onDetail: () => _showDetailBottomSheet(
                            item,
                            isService: _showServices,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // ================= BOTTOM NAV + QR TENGAH =================
      bottomNavigationBar: _BottomNavBar(
        onHomeTap: () {
          setState(() {
            _showServices = false;
          });
        },
        onOrderTap: () {
          _showAddPopup(context);
        },
        onSettingsTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengaturan ditekan')),
          );
        },
        onProfileTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil ditekan')),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CenterQrButton(
        onTap: _onScanQrTap,
      ),
    );
  }

  // ================= POPUP TAMBAH DATA =================

  void _showAddPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Tambah Data",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  leading: const Icon(
                    Icons.add_circle_rounded,   // ikon plus modern
                    color: Colors.orange,
                    size: 28,
                  ),
                  title: const Text("Tambah Barang Baru"),
                  onTap: () async {
                    Navigator.pop(context);
                    final result =
                        await Navigator.pushNamed(context, AppRoutes.addItem);
                    if (result is ItemModel) {
                      _itemService.addItem(result);
                    }
                  },
                ),

              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.build_circle_rounded),
                title: const Text("Tambah Item Service"),
                onTap: () async {
                  Navigator.pop(context);
                  final result =
                      await Navigator.pushNamed(context, AppRoutes.addService);
                  if (result is ItemModel) {
                    _serviceService.addService(result);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= DETAIL LENGKAP (BOTTOM SHEET) =================

  Future<void> _showDetailBottomSheet(
    ItemModel item, {
    required bool isService,
  }) async {
    Map<String, dynamic>? row;

    if (isService) {
      row = await _serviceService.getServiceRowById(item.id);
    } else {
      row = await _itemService.getItemRowById(item.id);
    }

    if (row == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data detail tidak ditemukan di database')),
        );
      }
      return;
    }

    final data = row; // non-null
    final String? imageUrl =
        data['image_url'] != null ? data['image_url'].toString() : null;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    isService ? 'Detail Item Service' : 'Detail Barang Baru',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (imageUrl != null && imageUrl.isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        imageUrl,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                if (imageUrl != null && imageUrl.isNotEmpty)
                  const SizedBox(height: 16),

                _detailRow('ID', data['id']?.toString() ?? '-'),
                _detailRow('Nama', data['name']?.toString() ?? '-'),

                if (isService)
                  _detailRow('Customer', data['customer']?.toString() ?? '-'),

                if (isService)
                  _detailRow('No. Seri / IMEI', data['sku']?.toString() ?? '-'),

                if (!isService)
                  _detailRow('Supplier', data['supplier']?.toString() ?? '-'),

                _detailRow('Kategori', data['category']?.toString() ?? '-'),

                if (!isService)
                  _detailRow('Kondisi', data['condition']?.toString() ?? '-'),

                if (data['harga'] != null)
                  _detailRow('Harga / Biaya', data['harga'].toString()),

                if (isService)
                  _detailRow('Status', data['status']?.toString() ?? '-'),

                _detailRow('Qty', data['total']?.toString() ?? '-'),

                if (data['date'] != null)
                  _detailRow('Tanggal', data['date'].toString()),

                if (data['created_at'] != null)
                  _detailRow('Dibuat', data['created_at'].toString()),

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= DIALOG EDIT LAMA (opsional) =================
  void _showEditDialog(ItemModel item, {required bool isService}) {
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Detail & Edit',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategori: ${item.category}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                'Stok saat ini: ${item.quantity}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (isService) {
                  _serviceService.removeService(item.id);
                } else {
                  _itemService.removeItem(item.id);
                }
                Navigator.pop(ctx);
              },
              child: const Text(
                'Hapus',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newQty = int.tryParse(qtyCtrl.text.trim());

                if (newName.isEmpty || newQty == null || newQty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama / jumlah tidak valid'),
                    ),
                  );
                  return;
                }

                final updated = ItemModel(
                  id: item.id,
                  name: newName,
                  category: item.category,
                  quantity: newQty,
                  imageUrl: item.imageUrl,
                );

                if (isService) {
                  _serviceService.updateService(updated);
                } else {
                  _itemService.updateItem(updated);
                }

                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}

// =====================================================
//  WIDGET KECIL
// =====================================================

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SquareIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.grey[700],
          size: 22,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF007BFF);
    const red = Color(0xFFFF3B30);
    const light = Color(0xFFEEEEEE);

    final bool isLight = color == light;
    final bool isMain = color == blue || color == red;

    final Color textColor =
        isMain ? Colors.white : Colors.black87;

    final child = Container(
      height: 82,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: selected
            ? Border.all(color: Colors.orangeAccent, width: 2)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isLight ? Colors.orange.withOpacity(0.15) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isLight ? Colors.orange : color,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.grey.shade200
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: isMain ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: child,
    );
  }
}


class _InventoryListCard extends StatelessWidget {
  final ItemModel item;
  final String? imageUrl;
  final bool isService;
  final VoidCallback onDetail;

  const _InventoryListCard({
    required this.item,
    required this.onDetail,
    required this.imageUrl,
    required this.isService,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);

    Widget leading;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _fallbackIcon();
          },
        ),
      );
    } else {
      leading = _fallbackIcon();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${item.quantity}',
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
     SizedBox(
  height: 34,
  child: TextButton.icon(
    onPressed: onDetail,
    style: TextButton.styleFrom(
      backgroundColor: const Color(0xFFE0E0E0), // abu-abu muda
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    icon: const Icon(
      Icons.info_outline_rounded,
      size: 16,
      color: Colors.black54, 
    ),
    label: const Text(
      'Detail',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black87, 
      ),
    ),
  ),
),

        ],
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isService ? Icons.build_rounded : Icons.inventory_2_rounded,
        color: Colors.grey[600],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onOrderTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;

  const _BottomNavBar({
    required this.onHomeTap,
    required this.onOrderTap,
    required this.onSettingsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: orange,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: onHomeTap,
          ),
          _NavItem(
            icon: Icons.add_circle_rounded,
            label: 'Order',
            onTap: onOrderTap,
          ),
          const SizedBox(width: 40),
          _NavItem(
            icon: Icons.settings_rounded,
            label: 'Pengaturan',
            onTap: onSettingsTap,
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profil',
            onTap: onProfileTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            const Icon(Icons.circle, size: 0), // spacer kecil
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
class _CenterQrButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterQrButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,        // Tombol putih
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(
          Icons.qr_code_scanner,      // Ikon scanner (bukan generator)
          size: 36,
          color: orange,              // Warna oranye agar terlihat
        ),
      ),
    );
  }
}
ashfvk
