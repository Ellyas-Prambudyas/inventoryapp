import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';
import '../services/inventory_service.dart';
import '../services/service_service.dart';

// ===================== WARNA (KONSISTEN) =====================
const Color kPrimary = Color(0xFFFF7A00);
const Color kBackground = Color(0xFFF5F5F5);
const Color kCardBg = Colors.white;
const Color kGreyBorder = Color(0xFFE3E3E3);
const Color kTextDark = Color(0xFF2E2E2E);
const Color kSuccess = Color(0xFF22C55E);
const Color kDanger = Color(0xFFEF4444);
const Color kLine = Color(0xFFE5E7EB);

enum _ScanMode { scan, search, history }

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  final _inventoryService = InventoryService();
  final _serviceService = ServiceService();

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  _ScanMode _mode = _ScanMode.scan;

  bool _isHandlingScan = false;
  bool _scanPaused = false;

  bool _isSearching = false;
  String? _lastError;
  ItemModel? _lastItem;
  String? _lastSource;

  double _zoom = 0.0; // 0..1

  final List<_ScanHistoryEntry> _history = [];
  List<ItemModel> _searchResults = [];

  // Animations
  late final AnimationController _modeAnim;
  late final AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _modeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _controller.dispose();
    _searchCtrl.dispose();
    _modeAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!mounted) return;
    try {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.detached) {
        await _controller.stop();
      } else if (state == AppLifecycleState.resumed) {
        if (!_scanPaused && _mode == _ScanMode.scan) {
          await _controller.start();
        }
      }
    } catch (_) {}
  }

  // ===================== UX HELPERS =====================
  void _showSnack(String message, {bool success = false}) {
    final color = success ? kSuccess : kDanger;
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.all(16),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  void _addHistory({
    required String raw,
    ItemModel? item,
    String? error,
    String? source,
  }) {
    final entry = _ScanHistoryEntry(
      raw: raw,
      item: item,
      error: error,
      source: source,
      time: DateTime.now(),
    );
    setState(() {
      _history.insert(0, entry);
      if (_history.length > 25) _history.removeLast();
    });
  }

  // ===================== SCAN CORE =====================
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_mode != _ScanMode.scan) return;
    if (_scanPaused) return;
    if (_isHandlingScan) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    final text = raw.trim();

    setState(() {
      _isHandlingScan = true;
      _lastError = null;
      _lastItem = null;
      _lastSource = null;
    });

    HapticFeedback.mediumImpact();

    try {
      await _controller.stop(); // stop sebentar biar tidak spam

      ItemModel? item;
      String sourceType = 'scan';

      final itemFromItems = await _inventoryService.getItemByQr(text);
      if (itemFromItems != null) {
        item = itemFromItems;
        sourceType = 'scan_item';
      }

      if (item == null) {
        final itemFromService = await _serviceService.getServiceByQr(text);
        if (itemFromService != null) {
          item = itemFromService;
          sourceType = 'scan_service';
        }
      }

      if (!mounted) return;

      if (item == null) {
        final err = 'Data tidak ditemukan untuk QR ini (items & services).';
        setState(() {
          _lastError = err;
          _lastItem = null;
          _lastSource = 'scan_not_found';
        });
        _addHistory(raw: text, error: err, source: 'scan_not_found');
        _showSnack('Data tidak ditemukan untuk QR ini.');
      } else {
        setState(() {
          _lastItem = item;
          _lastError = null;
          _lastSource = sourceType;
        });
        _addHistory(raw: text, item: item, source: sourceType);

        // animasi “success feel”
        HapticFeedback.lightImpact();
        await _showItemDetailSheet(item, source: sourceType, raw: text);
      }
    } catch (_) {
      if (!mounted) return;
      final err = 'Terjadi kesalahan saat mengambil data.';
      setState(() {
        _lastError = err;
        _lastItem = null;
        _lastSource = 'scan_error';
      });
      _addHistory(raw: text, error: err, source: 'scan_error');
      _showSnack(err);
    } finally {
      if (!mounted) return;
      try {
        if (!_scanPaused && _mode == _ScanMode.scan) {
          await _controller.start();
        }
      } catch (_) {}
      if (mounted) setState(() => _isHandlingScan = false);
    }
  }

  Future<void> _togglePauseScan() async {
    try {
      if (_scanPaused) {
        setState(() => _scanPaused = false);
        if (_mode == _ScanMode.scan) await _controller.start();
      } else {
        setState(() => _scanPaused = true);
        await _controller.stop();
      }
    } catch (_) {}
  }

  // ===================== SEARCH =====================
  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), _onManualSearch);
  }

  Future<void> _onManualSearch() async {
    if (_mode != _ScanMode.search) return;

    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _isSearching = true;
      _lastError = null;
    });

    try {
      final itemResults = await _inventoryService.searchItems(keyword);
      final serviceResults = await _serviceService.searchServices(keyword);

      if (!mounted) return;
      final results = [...itemResults, ...serviceResults];

      setState(() {
        _searchResults = results;
        _lastError = results.isEmpty ? 'Tidak ada data yang cocok dengan "$keyword".' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _lastError = 'Terjadi kesalahan saat mencari data.';
      });
      _showSnack('Terjadi kesalahan saat mencari data.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _lastError = null;
    });
  }

  // ===================== MANUAL QR INPUT (MODERN) =====================
  Future<void> _openManualQrInput() async {
    final ctrl = TextEditingController();
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;

          return SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
              child: _GlassSheet(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sheetHandle(),
                    Row(
                      children: [
                        _iconBadge(Icons.qr_code_rounded),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Input QR Manual',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              color: kTextDark,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Tempelkan QR value di sini...',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: kLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: kLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: kPrimary, width: 1.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              final text = (data?.text ?? '').trim();
                              if (text.isEmpty) {
                                if (mounted) _showSnack('Clipboard kosong.');
                                return;
                              }
                              ctrl.text = text;
                            },
                            icon: const Icon(Icons.paste_rounded),
                            label: const Text('Paste'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              final text = ctrl.text.trim();
                              if (text.isEmpty) {
                                if (mounted) _showSnack('QR value tidak boleh kosong.');
                                return;
                              }
                              Navigator.of(ctx).pop(text);
                            },
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('Cari'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final text = (result ?? '').trim();
      if (text.isEmpty) return;

      await _handleManualQr(text);
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _handleManualQr(String text) async {
    setState(() {
      _isHandlingScan = true;
      _lastError = null;
      _lastItem = null;
      _lastSource = 'manual_qr';
    });

    try {
      ItemModel? item;
      String sourceType = 'manual_qr';

      final itemFromItems = await _inventoryService.getItemByQr(text);
      if (itemFromItems != null) {
        item = itemFromItems;
        sourceType = 'scan_item';
      }

      if (item == null) {
        final itemFromService = await _serviceService.getServiceByQr(text);
        if (itemFromService != null) {
          item = itemFromService;
          sourceType = 'scan_service';
        }
      }

      if (!mounted) return;

      if (item == null) {
        final err = 'Data tidak ditemukan untuk kode ini.';
        setState(() {
          _lastError = err;
          _lastItem = null;
          _lastSource = 'manual_not_found';
        });
        _addHistory(raw: text, error: err, source: 'manual_not_found');
        _showSnack(err);
      } else {
        setState(() {
          _lastItem = item;
          _lastError = null;
          _lastSource = sourceType;
        });
        _addHistory(raw: text, item: item, source: sourceType);
        await _showItemDetailSheet(item, source: sourceType, raw: text);
      }
    } catch (_) {
      if (!mounted) return;
      final err = 'Terjadi kesalahan saat mengambil data.';
      setState(() {
        _lastError = err;
        _lastItem = null;
        _lastSource = 'manual_error';
      });
      _addHistory(raw: text, error: err, source: 'manual_error');
      _showSnack(err);
    } finally {
      if (mounted) setState(() => _isHandlingScan = false);
    }
  }

  // ===================== DETAIL SHEET + ACTIONS (MODERN) =====================
  Future<void> _showItemDetailSheet(
    ItemModel item, {
    String? source,
    String? raw,
  }) async {
    final bool isService = source == 'scan_service';
    final bool canEditDelete = source == 'scan_item' || source == 'scan_service';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(
        item: item,
        source: source,
        raw: raw,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Edit Data', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama')),
              const SizedBox(height: 10),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, elevation: 0),
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

                  await client.from(table).update({'name': newName, 'total': newQty}).eq('id', item.id);

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
                } catch (_) {
                  _showSnack('Gagal menyimpan perubahan');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    qtyCtrl.dispose();
  }

  Future<void> _confirmDeleteFromScan(
    ItemModel item, {
    required bool isService,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Hapus Data', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text('Yakin ingin menghapus data ini dari database?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
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
    } catch (_) {
      _showSnack('Gagal menghapus data');
    }
  }

  // ===================== UI =====================
  Future<void> _setMode(_ScanMode m) async {
    if (_mode == m) return;

    setState(() => _mode = m);
    _modeAnim.forward(from: 0);

    try {
      if (m == _ScanMode.scan && !_scanPaused) {
        await _controller.start();
      } else {
        await _controller.stop();
      }
    } catch (_) {}
  }

  Widget _modeTabs() {
    return _SegmentedTabs(
      mode: _mode,
      onChanged: _setMode,
    );
  }

  Widget _scannerCard() {
    return _GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Kamera
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _scanPaused ? 0.65 : 1.0,
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                  ),

                  // Overlay animasi modern
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => _ModernScanOverlay(
                        pulse: _pulseAnim.value,
                        paused: _scanPaused,
                      ),
                    ),
                  ),

                  // Hint bar
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _hintBar(
                      title: 'Arahkan ke QR code',
                      subtitle: _scanPaused
                          ? 'Scan dijeda. Tap Resume untuk lanjut.'
                          : 'Scan untuk Barang & Service',
                      icon: Icons.info_outline_rounded,
                    ),
                  ),

                  // Loading overlay
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: !_isHandlingScan
                        ? const SizedBox.shrink()
                        : Container(
                            key: const ValueKey('loading'),
                            color: Colors.black.withOpacity(0.35),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.6,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Memproses...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Controls modern (wrap biar responsif)
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final itemW = (w - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemW,
                    child: _miniAction(
                      icon: Icons.flash_on_rounded,
                      label: 'Flash',
                      onTap: () => _controller.toggleTorch(),
                      filled: false,
                    ),
                  ),
                  SizedBox(
                    width: itemW,
                    child: _miniAction(
                      icon: Icons.cameraswitch_rounded,
                      label: 'Kamera',
                      onTap: () => _controller.switchCamera(),
                      filled: false,
                    ),
                  ),
                  SizedBox(
                    width: itemW,
                    child: _miniAction(
                      icon: _scanPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      label: _scanPaused ? 'Resume' : 'Pause',
                      onTap: _togglePauseScan,
                      filled: true,
                    ),
                  ),
                  SizedBox(
                    width: itemW,
                    child: _miniAction(
                      icon: Icons.keyboard_rounded,
                      label: 'Manual',
                      onTap: _openManualQrInput,
                      filled: false,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // Zoom modern
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.zoom_out_rounded, color: Colors.black54),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    onChanged: (v) async {
                      setState(() => _zoom = v);
                      try {
                        await _controller.setZoomScale(v);
                      } catch (_) {}
                    },
                    activeColor: kPrimary,
                    inactiveColor: Colors.black12,
                  ),
                ),
                const Icon(Icons.zoom_in_rounded, color: Colors.black54),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cari data',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: kTextDark),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onChanged: _scheduleSearch,
            onSubmitted: (_) => _onManualSearch(),
            decoration: InputDecoration(
              hintText: 'Nama / SKU / merk / customer...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else ...[
                    IconButton(
                      onPressed: _onManualSearch,
                      tooltip: 'Cari',
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    IconButton(
                      onPressed: _clearSearch,
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kLine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kLine),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kPrimary, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_lastError != null) _infoBox(_lastError!, danger: true),
          if (_lastError == null && _searchResults.isEmpty)
            _infoBox('Ketik kata kunci untuk mencari barang/service.', danger: false),
          const SizedBox(height: 10),
          if (_searchResults.isNotEmpty)
            SizedBox(
              height: 360,
              child: ListView.separated(
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 8),
                        child: child,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _showItemDetailSheet(item, source: 'search', raw: null),
                      leading: CircleAvatar(
                        backgroundColor: kPrimary.withOpacity(0.14),
                        child: Text(
                          item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w900),
                        ),
                      ),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, color: kTextDark)),
                      subtitle: Text(item.category, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: kPrimary),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Riwayat',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: kTextDark),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _history.clear()),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Bersihkan'),
                style: TextButton.styleFrom(foregroundColor: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_history.isEmpty) _infoBox('Belum ada riwayat scan.', danger: false),
          if (_history.isNotEmpty)
            SizedBox(
              height: 420,
              child: ListView.separated(
                itemCount: _history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final h = _history[index];
                  final ok = h.item != null && h.error == null;
                  final title = ok ? h.item!.name : 'Tidak ditemukan / Error';
                  final subtitle = ok
                      ? 'Qty: ${h.item!.quantity} • ${h.item!.category}'
                      : (h.error ?? 'Tidak ada data');

                  return ListTile(
                    onTap: ok ? () => _showItemDetailSheet(h.item!, source: h.source, raw: h.raw) : null,
                    leading: CircleAvatar(
                      backgroundColor: (ok ? kSuccess : kDanger).withOpacity(0.14),
                      child: Icon(
                        ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: ok ? kSuccess : kDanger,
                      ),
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '$subtitle\n${_fmtTime(h.time)} • ${_sourceLabel(h.source)}',
                      style: const TextStyle(fontSize: 12, height: 1.25),
                    ),
                    isThreeLine: true,
                    trailing: ok ? const Icon(Icons.chevron_right_rounded, color: kPrimary) : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _sourceLabel(String? s) {
    switch (s) {
      case 'scan_item':
        return 'Scan • Barang';
      case 'scan_service':
        return 'Scan • Service';
      case 'scan_not_found':
        return 'Scan • Tidak ditemukan';
      case 'scan_error':
        return 'Scan • Error';
      case 'manual_not_found':
        return 'Manual • Tidak ditemukan';
      case 'manual_error':
        return 'Manual • Error';
      default:
        return 'Lainnya';
    }
  }

  Widget _hintBar({required String title, required String subtitle, required IconData icon}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.92), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        decoration: BoxDecoration(
          color: filled ? kPrimary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: filled ? kPrimary : kLine),
          boxShadow: filled
              ? [BoxShadow(color: kPrimary.withOpacity(0.22), blurRadius: 12, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : Colors.black87),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, color: filled ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String text, {required bool danger}) {
    final bg = danger ? kDanger.withOpacity(0.08) : kPrimary.withOpacity(0.08);
    final bd = danger ? kDanger.withOpacity(0.18) : kPrimary.withOpacity(0.18);
    final ic = danger ? kDanger : kPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bd),
      ),
      child: Row(
        children: [
          Icon(danger ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: ic),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Scan QR', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Input QR manual',
            onPressed: _openManualQrInput,
            icon: const Icon(Icons.keyboard_rounded),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kLine),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          children: [
            _modeTabs(),
            const SizedBox(height: 14),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_mode),
                child: () {
                  if (_mode == _ScanMode.scan) return _scannerCard();
                  if (_mode == _ScanMode.search) return _searchCard();
                  return _historyCard();
                }(),
              ),
            ),

            const SizedBox(height: 14),

            if (_lastItem != null || _lastError != null)
              _GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _lastError != null ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                      color: _lastError != null ? kDanger : kSuccess,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _lastError != null
                          ? Text(
                              _lastError!,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: kDanger),
                            )
                          : Text(
                              'Terakhir: ${_lastItem!.name} • Qty: ${_lastItem!.quantity} • ${_sourceLabel(_lastSource)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, color: kTextDark),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ===================== SEGMENTED TABS (MODERN) =====================
class _SegmentedTabs extends StatelessWidget {
  final _ScanMode mode;
  final Future<void> Function(_ScanMode) onChanged;

  const _SegmentedTabs({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    int index = 0;
    if (mode == _ScanMode.search) index = 1;
    if (mode == _ScanMode.history) index = 2;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kLine),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth;
          final itemW = (w - 12) / 3;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: index * (itemW + 6),
                top: 0,
                bottom: 0,
                width: itemW,
                child: Container(
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(color: kPrimary.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _segItem(
                    width: itemW,
                    selected: mode == _ScanMode.scan,
                    icon: Icons.qr_code_scanner_rounded,
                    text: 'Scan',
                    onTap: () => onChanged(_ScanMode.scan),
                  ),
                  const SizedBox(width: 6),
                  _segItem(
                    width: itemW,
                    selected: mode == _ScanMode.search,
                    icon: Icons.search_rounded,
                    text: 'Cari',
                    onTap: () => onChanged(_ScanMode.search),
                  ),
                  const SizedBox(width: 6),
                  _segItem(
                    width: itemW,
                    selected: mode == _ScanMode.history,
                    icon: Icons.history_rounded,
                    text: 'Riwayat',
                    onTap: () => onChanged(_ScanMode.history),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segItem({
    required double width,
    required bool selected,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      height: 44,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.black54),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== SCAN OVERLAY (ULTRA MODERN) =====================
class _ModernScanOverlay extends StatelessWidget {
  final double pulse; // 0..1
  final bool paused;

  const _ModernScanOverlay({
    required this.pulse,
    required this.paused,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = c.maxWidth * 0.72;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                // Frame + corners
                CustomPaint(
                  painter: _ScanFramePainter(
                    glow: paused ? 0.15 : (0.25 + 0.35 * pulse),
                    paused: paused,
                  ),
                  child: const SizedBox.expand(),
                ),

                // Scan line moving (loop)
                if (!paused)
                  _MovingScanLine(),
                if (paused)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pause_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Paused',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MovingScanLine extends StatefulWidget {
  @override
  State<_MovingScanLine> createState() => _MovingScanLineState();
}

class _MovingScanLineState extends State<_MovingScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value; // 0..1
        final y = lerpDouble(0.12, 0.88, t)!;

        return Align(
          alignment: Alignment(0, (y * 2) - 1),
          child: Container(
            height: 2.2,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.90),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(color: Colors.white.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final double glow; // 0..1
  final bool paused;

  _ScanFramePainter({required this.glow, required this.paused});

  @override
  void paint(Canvas canvas, Size size) {
    final r = 26.0;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));

    // Outer subtle border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.white.withOpacity(paused ? 0.35 : 0.85);

    canvas.drawRRect(rect, borderPaint);

    // Glow corners
    final cornerLen = size.width * 0.18;
    final stroke = 4.0;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.15 + glow);

    void corner(Offset o, double dx, double dy) {
      // dx/dy sign for direction
      final path = Path()
        ..moveTo(o.dx, o.dy + dy * cornerLen)
        ..lineTo(o.dx, o.dy)
        ..lineTo(o.dx + dx * cornerLen, o.dy);

      canvas.drawPath(path, glowPaint);
    }

    corner(Offset(16, 16), 1, 1); // top-left
    corner(Offset(size.width - 16, 16), -1, 1); // top-right
    corner(Offset(16, size.height - 16), 1, -1); // bottom-left
    corner(Offset(size.width - 16, size.height - 16), -1, -1); // bottom-right

    // Inner vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(paused ? 0.25 : 0.18),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset(size.width / 2, size.height / 2) & size);

    canvas.drawRRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.glow != glow || oldDelegate.paused != paused;
  }
}

// ===================== HISTORY MODEL =====================
class _ScanHistoryEntry {
  final String raw;
  final ItemModel? item;
  final String? error;
  final String? source;
  final DateTime time;

  _ScanHistoryEntry({
    required this.raw,
    required this.item,
    required this.error,
    required this.source,
    required this.time,
  });
}

// ===================== BOTTOM SHEET DETAIL ITEM (MODERN) =====================
class _ItemDetailSheet extends StatelessWidget {
  final ItemModel item;
  final String? source;
  final String? raw;
  final bool showActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ItemDetailSheet({
    required this.item,
    this.source,
    this.raw,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String sourceText = '';
    if (source == 'scan_item') sourceText = 'Ditemukan dari scan QR (Barang)';
    if (source == 'scan_service') sourceText = 'Ditemukan dari scan QR (Service)';
    if (source == 'search') sourceText = 'Ditemukan dari pencarian manual';

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (context, scrollController) {
        return _GlassSheet(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(),
                Row(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: kPrimary.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: kPrimary, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _pill(text: item.category, filled: false),
                              _pill(text: 'Qty: ${item.quantity}', filled: true),
                            ],
                          ),
                          if (sourceText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(sourceText, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if ((raw ?? '').isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kLine),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_rounded, color: Colors.black54),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            raw!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: raw!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('QR value disalin'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          tooltip: 'Copy',
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Text(
                  'Ringkasan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 10),
                _DetailRow(label: 'Nama', value: item.name, icon: Icons.label_important_outline_rounded),
                _DetailRow(label: 'Kategori', value: item.category, icon: Icons.category_rounded),
                _DetailRow(label: 'Qty', value: '${item.quantity}', icon: Icons.inventory_2_rounded),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGreyBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: kPrimary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Jika Anda mau, detail tambahan seperti SKU, harga, customer, status service, dan foto bisa dimunculkan di sheet ini.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.2,
                            height: 1.25,
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onEdit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _pill({required String text, required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? kPrimary : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? kPrimary : kLine),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: filled ? Colors.white : Colors.black87,
        ),
      ),
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
    if (value.isEmpty) return const SizedBox.shrink();
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
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900, color: kTextDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== SMALL UI PARTS =====================
Widget _sheetHandle() {
  return Center(
    child: Container(
      width: 44,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12, top: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

Widget _iconBadge(IconData icon) {
  return Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: kPrimary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kPrimary.withOpacity(0.18)),
    ),
    child: Icon(icon, color: kPrimary),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassCard({
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLine),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;

  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: kLine),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: child,
        ),
      ),
    );
  }
}
