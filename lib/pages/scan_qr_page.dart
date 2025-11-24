import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';
import '../services/inventory_service.dart';
import '../services/service_service.dart';

// ===================== WARNA (DISESUAIKAN TEMA BARU) =====================

const Color kPrimary = Color(0xFFFF7A00); // oranye utama (sama seperti Home)
const Color kBackground = Color(0xFFF5F5F5); // abu-abu lembut
const Color kCardBg = Colors.white; // kartu putih
const Color kGreyBorder = Color(0xFFE3E3E3);
const Color kTextDark = Color(0xFF2E2E2E);

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  final _inventoryService = InventoryService();
  final _serviceService = ServiceService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isHandlingScan = false;
  bool _isSearching = false;

  String? _lastError;
  ItemModel? _lastItem;
  List<ItemModel> _searchResults = [];

  // ===================== SNACK RINGKAS =====================

  void _showSnack(String message, {bool success = false}) {
    final color = success ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ===================== SCAN QR =====================

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isHandlingScan) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final barcode = barcodes.first;
    final raw = barcode.rawValue;

    if (raw == null || raw.isEmpty) return;

    setState(() {
      _isHandlingScan = true;
      _lastError = null;
    });

    HapticFeedback.mediumImpact();

    try {
      await _controller.stop(); // pause biar tidak spam

      final text = raw.trim();
      ItemModel? item;
      String sourceType = 'scan';

      // 1. Coba cari di tabel items (barang baru)
      final itemFromItems = await _inventoryService.getItemByQr(text);
      if (itemFromItems != null) {
        item = itemFromItems;
        sourceType = 'scan_item';
      }

      // 2. Kalau belum ketemu, coba di tabel services (item service)
      if (item == null) {
        final itemFromService = await _serviceService.getServiceByQr(text);
        if (itemFromService != null) {
          item = itemFromService;
          sourceType = 'scan_service';
        }
      }

      if (!mounted) return;

      if (item == null) {
        setState(() {
          _lastItem = null;
          _lastError = 'Data tidak ditemukan untuk QR ini (items & services).';
        });
        _showSnack('Data tidak ditemukan untuk QR ini.');
      } else {
        setState(() {
          _lastItem = item;
          _lastError = null;
        });

        await _showItemDetailSheet(item, source: sourceType);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastItem = null;
        _lastError = 'Terjadi kesalahan saat mengambil data.';
      });
      _showSnack('Terjadi kesalahan saat mengambil data.');
    } finally {
      if (mounted) {
        await _controller.start();
        setState(() {
          _isHandlingScan = false;
        });
      }
    }
  }

  // ===================== SEARCH MANUAL =====================

  Future<void> _onManualSearch() async {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) {
      _showSnack('Masukkan nama barang / SKU dulu.');
      return;
    }

    setState(() {
      _isSearching = true;
      _lastError = null;
    });

    try {
      // cari di items + services
      final itemResults = await _inventoryService.searchItems(keyword);
      final serviceResults = await _serviceService.searchServices(keyword);
      final results = [...itemResults, ...serviceResults];

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        if (results.isEmpty) {
          _lastError = 'Tidak ada data yang cocok dengan "$keyword".';
        } else {
          _lastError = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _lastError = 'Terjadi kesalahan saat mencari data.';
      });
      _showSnack('Terjadi kesalahan saat mencari data.');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // ===================== BOTTOM SHEET DETAIL + AKSI =====================

  Future<void> _showItemDetailSheet(
    ItemModel item, {
    String? source,
  }) async {
    final bool isService = source == 'scan_service';
    final bool canEditDelete =
        source == 'scan_item' || source == 'scan_service';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(
        item: item,
        source: source,
        showActions: canEditDelete,
        onEdit: !canEditDelete
            ? null
            : () {
                Navigator.of(context).pop();
                _showEditDialogFromScan(item, isService: isService);
              },
        onDelete: !canEditDelete
            ? null
            : () {
                Navigator.of(context).pop();
                _confirmDeleteFromScan(item, isService: isService);
              },
      ),
    );
  }

  Future<void> _showEditDialogFromScan(
    ItemModel item, {
    required bool isService,
  }) async {
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Edit Data',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                final newQty = int.tryParse(qtyCtrl.text.trim());

                if (newName.isEmpty || newQty == null || newQty <= 0) {
                  _showSnack('Nama / Qty tidak valid');
                  return;
                }

                try {
                  final client = Supabase.instance.client;
                  final table = isService ? 'services' : 'items';

                  await client
                      .from(table)
                      .update({'name': newName, 'total': newQty}).eq('id', item.id);

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
                    _inventoryService.updateItem(updated);
                  }

                  if (mounted) {
                    Navigator.of(ctx).pop();
                    _showSnack('Data berhasil disimpan', success: true);
                  }
                } catch (e) {
                  _showSnack('Gagal menyimpan perubahan');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteFromScan(
    ItemModel item, {
    required bool isService,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Hapus Data',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Yakin ingin menghapus data ini dari database?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Hapus',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      final client = Supabase.instance.client;
      final table = isService ? 'services' : 'items';

      await client.from(table).delete().eq('id', item.id);

      if (isService) {
        _serviceService.removeService(item.id);
      } else {
        _inventoryService.removeItem(item.id);
      }

      _showSnack('Data berhasil dihapus', success: true);
    } catch (e) {
      _showSnack('Gagal menghapus data');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===================== WIDGET KECIL =====================

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _controller.toggleTorch(),
          icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
          tooltip: 'Flash',
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: () => _controller.switchCamera(),
          icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
          tooltip: 'Ganti Kamera',
        ),
      ],
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.75;
        final height = width;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 3,
                ),
              ),
            ),
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Align(
                    alignment: Alignment(0, value * 2 - 1),
                    child: Container(
                      width: width * 0.9,
                      height: 2,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLastInfoCard(ThemeData theme) {
    if (_lastItem == null && _lastError == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              _lastError != null
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: _lastError != null ? Colors.redAccent : kPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _lastError != null
                  ? Text(
                      _lastError!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : Text(
                      'Terakhir: ${_lastItem!.name} (qty: ${_lastItem!.quantity})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: kTextDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.white.withOpacity(0.95),
        child: ListView.separated(
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _searchResults[index];
            return ListTile(
              onTap: () => _showItemDetailSheet(item, source: 'search'),
              leading: CircleAvatar(
                backgroundColor: kPrimary.withOpacity(0.15),
                child: Text(
                  item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                ),
              ),
              subtitle: Text(
                item.category,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: kPrimary,
              ),
            );
          },
        ),
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Scan / Cari Barang',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kPrimary,
              kBackground,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'Arahkan kamera ke QR code',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bisa untuk barang baru dan item service.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),

              // SCANNER
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                        ),
                      ),
                      _buildScannerOverlay(context),
                      if (_isHandlingScan)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              _buildControls(),
              const SizedBox(height: 8),

              // BAGIAN BAWAH: SEARCH + STATUS + HASIL
              Expanded(
                flex: 3,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _onManualSearch(),
                        decoration: InputDecoration(
                          hintText: 'Cari nama / SKU / merk / customer...',
                          hintStyle: const TextStyle(fontSize: 13),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.tune_rounded),
                                  onPressed: _onManualSearch,
                                  tooltip: 'Cari',
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(color: kGreyBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: const BorderSide(color: kGreyBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide:
                                const BorderSide(color: kPrimary, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      _buildLastInfoCard(theme),

                      const SizedBox(height: 8),

                      Expanded(
                        child: _buildSearchResults(theme),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== BOTTOM SHEET DETAIL ITEM =====================

class _ItemDetailSheet extends StatelessWidget {
  final ItemModel item;
  final String? source;
  final bool showActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ItemDetailSheet({
    required this.item,
    this.source,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String sourceText = '';
    if (source == 'scan_item') {
      sourceText = 'Ditemukan dari scan QR (Barang Baru)';
    }
    if (source == 'scan_service') {
      sourceText = 'Ditemukan dari scan QR (Item Service)';
    }
    if (source == 'search') {
      sourceText = 'Ditemukan dari pencarian manual';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: kPrimary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Chip(
                                label: Text(
                                  item.category,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: kBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                  side: const BorderSide(color: kPrimary),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  'Qty: ${item.quantity}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Colors.white,
                              ),
                            ],
                          ),
                          if (sourceText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              sourceText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Ringkasan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Nama Barang',
                  value: item.name,
                  icon: Icons.label_important_outline_rounded,
                ),
                _DetailRow(
                  label: 'Kategori',
                  value: item.category,
                  icon: Icons.category_rounded,
                ),
                _DetailRow(
                  label: 'Qty',
                  value: '${item.quantity}',
                  icon: Icons.inventory_2_rounded,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGreyBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: kPrimary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Detail lengkap lain (SKU, harga, customer, dll) bisa ditambahkan nanti sesuai kebutuhan.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showActions) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Hapus'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onEdit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                          ),
                          child: const Text('Edit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===================== DETAIL ROW =====================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kPrimary),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: kTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
