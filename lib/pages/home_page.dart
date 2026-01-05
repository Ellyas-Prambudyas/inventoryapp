// ===================== home_page.dart (FULL) =====================
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';
import '../routes/app_routes.dart';
import '../services/inventory_service.dart';
import '../services/service_service.dart';
import '../services/stock_out_service.dart';

const Color kHomeBg = Color(0xFFF6F7FB);
const Color kOrange = Color(0xFFFF7A00);

const Color kDark = Color(0xFF0F172A);
const Color kLine = Color(0xFFE5E7EB);

const Color kRed = Color(0xFFEF4444);
const Color kGreen = Color(0xFF22C55E);
const Color kGrayActive = Color(0xFF6B7280);

const Color kGlassBase = Color(0xFF0B1220);

enum ServiceFilter { active, done }
enum ItemSort { newest, nameAZ, qtyHigh, qtyLow }
enum ServiceSort { newest, nameAZ }

class ItemFilterState {
  final bool inStockOnly;
  final Set<String> categories;
  final RangeValues qtyRange;
  final ItemSort sort;

  const ItemFilterState({
    required this.inStockOnly,
    required this.categories,
    required this.qtyRange,
    required this.sort,
  });

  factory ItemFilterState.initial({required double minQty, required double maxQty}) {
    final safeMax = maxQty == minQty ? (minQty + 1) : maxQty;
    return ItemFilterState(
      inStockOnly: true,
      categories: <String>{},
      qtyRange: RangeValues(minQty, safeMax),
      sort: ItemSort.newest,
    );
  }

  ItemFilterState copyWith({
    bool? inStockOnly,
    Set<String>? categories,
    RangeValues? qtyRange,
    ItemSort? sort,
  }) {
    return ItemFilterState(
      inStockOnly: inStockOnly ?? this.inStockOnly,
      categories: categories ?? this.categories,
      qtyRange: qtyRange ?? this.qtyRange,
      sort: sort ?? this.sort,
    );
  }
}

class ServiceFilterState {
  final ServiceFilter status;
  final ServiceSort sort;

  const ServiceFilterState({required this.status, required this.sort});

  factory ServiceFilterState.initial() => const ServiceFilterState(
        status: ServiceFilter.active,
        sort: ServiceSort.newest,
      );

  ServiceFilterState copyWith({ServiceFilter? status, ServiceSort? sort}) {
    return ServiceFilterState(
      status: status ?? this.status,
      sort: sort ?? this.sort,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _itemService = InventoryService();
  final _serviceService = ServiceService();
  final _stockOutService = StockOutService();

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  bool _showServices = false;
  ServiceFilterState _serviceUiFilter = ServiceFilterState.initial();
  ItemFilterState? _itemFilter;

  @override
  void initState() {
    super.initState();
    _itemService.loadItems();
    _serviceService.loadServices();
    _stockOutService.loadTotalOut();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScanQrTap() => Navigator.pushNamed(context, AppRoutes.scanQr);
  void _openNotifications() => Navigator.pushNamed(context, AppRoutes.notifications);
  void _openProfile() => Navigator.pushNamed(context, AppRoutes.profile);
  void _openSettings() => Navigator.pushNamed(context, AppRoutes.settings);
  void _openStockOutHistory() => Navigator.pushNamed(context, AppRoutes.stockOutHistory);

  double _minQty(List<ItemModel> items) {
    if (items.isEmpty) return 0;
    final m = items.map((e) => e.quantity).reduce((a, b) => a < b ? a : b);
    return m.toDouble();
  }

  double _maxQty(List<ItemModel> items) {
    if (items.isEmpty) return 0;
    final m = items.map((e) => e.quantity).reduce((a, b) => a > b ? a : b);
    return m.toDouble();
  }

  List<ItemModel> _applyItemFilter(List<ItemModel> items) {
    final f = _itemFilter;
    if (f == null) return items;

    var out = items;

    if (f.inStockOnly) out = out.where((e) => e.quantity > 0).toList();
    if (f.categories.isNotEmpty) out = out.where((e) => f.categories.contains(e.category)).toList();

    out = out.where((e) => e.quantity >= f.qtyRange.start && e.quantity <= f.qtyRange.end).toList();

    out.sort((a, b) {
      switch (f.sort) {
        case ItemSort.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ItemSort.qtyHigh:
          return b.quantity.compareTo(a.quantity);
        case ItemSort.qtyLow:
          return a.quantity.compareTo(b.quantity);
        case ItemSort.newest:
        default:
          return b.id.compareTo(a.id);
      }
    });

    return out;
  }

  List<ItemModel> _applyServiceFilter(List<ItemModel> services) {
    var out = services;

    out = out.where((s) {
      final lower = s.category.toLowerCase();
      final isDone = lower.contains('(selesai)');
      if (_serviceUiFilter.status == ServiceFilter.active) return !isDone;
      return isDone;
    }).toList();

    out.sort((a, b) {
      switch (_serviceUiFilter.sort) {
        case ServiceSort.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ServiceSort.newest:
        default:
          return b.id.compareTo(a.id);
      }
    });

    return out;
  }

  Future<void> _showStockOutDialog(ItemModel item) async {
    final qtyCtrl = TextEditingController();
    try {
      String? errorText;

      final int? outQty = await showModalBottomSheet<int>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.55),
        builder: (sheetCtx) {
          final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;

          return StatefulBuilder(
            builder: (sheetCtx, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
                child: _BottomSheetShell(
                  title: 'Keluarkan Stok',
                  subtitle: item.name,
                  icon: Icons.exit_to_app_rounded,
                  accent: kRed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoPill(icon: Icons.inventory_2_rounded, text: 'Stok saat ini: ${item.quantity}'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) {
                          if (errorText != null) setSheetState(() => errorText = null);
                        },
                        decoration: _modernFieldDec(
                          label: 'Jumlah yang dikeluarkan',
                          hint: 'Contoh: 1',
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetCtx).pop(),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                side: const BorderSide(color: kLine),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final out = int.tryParse(qtyCtrl.text.trim());
                                if (out == null || out <= 0) {
                                  setSheetState(() => errorText = 'Jumlah keluar tidak valid');
                                  return;
                                }
                                if (out > item.quantity) {
                                  setSheetState(() => errorText = 'Jumlah keluar melebihi stok');
                                  return;
                                }
                                Navigator.of(sheetCtx).pop(out);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kRed,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (!mounted || outQty == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      bool ok = false;
      bool logged = false;

      try {
        final newTotal = item.quantity - outQty;
        ok = await _itemService.updateItemRemote(item.id, total: newTotal);

        if (ok) {
          logged = await _stockOutService.insertOut(
            refType: 'ITEM',
            refId: item.id.toString(),
            name: item.name,
            qty: outQty,
            note: 'Barang keluar',
          );
        }
      } catch (_) {
        ok = false;
        logged = false;
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      if (ok) {
        _itemService.loadItems();
        _stockOutService.loadTotalOut();
        _showSnack(logged ? 'Stok berhasil dikurangi' : 'Stok berkurang, tapi gagal mencatat data keluar', success: logged);
      } else {
        _showSnack('Gagal mengurangi stok', success: false);
      }
    } finally {
      qtyCtrl.dispose();
    }
  }

  void _showAddPopup(BuildContext context) {
    Future<void> openRouteAndHandle(
      BuildContext sheetCtx,
      String routeName,
      void Function(ItemModel) onOk,
    ) async {
      Navigator.of(sheetCtx).pop();
      final result = await Navigator.pushNamed(context, routeName);
      if (result is ItemModel) onOk(result);
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      isScrollControlled: false,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _BottomSheetShell(
              title: 'Tambah Data',
              subtitle: 'Pilih jenis input',
              icon: Icons.add_circle_rounded,
              accent: kOrange,
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.add_box_rounded,
                    title: 'Tambah Barang Baru',
                    subtitle: 'Input item baru ke inventori',
                    accent: kOrange,
                    onTap: () => openRouteAndHandle(sheetCtx, AppRoutes.addItem, (item) => _itemService.addItem(item)),
                  ),
                  const SizedBox(height: 10),
                  _ActionTile(
                    icon: Icons.build_circle_rounded,
                    title: 'Tambah Item Service',
                    subtitle: 'Input layanan/service baru',
                    accent: kGrayActive,
                    onTap: () => openRouteAndHandle(sheetCtx, AppRoutes.addService, (item) => _serviceService.addService(item)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFilterSheet(List<ItemModel> currentList) async {
    if (_showServices) {
      final applied = await showModalBottomSheet<ServiceFilterState>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withOpacity(0.55),
        builder: (ctx) {
          ServiceFilterState temp = _serviceUiFilter;

          return _FilterSheetContainer(
            title: 'Filter Perbaikan',
            onClear: () => Navigator.of(ctx).pop(ServiceFilterState.initial()),
            onApply: () => Navigator.of(ctx).pop(temp),
            child: StatefulBuilder(
              builder: (ctx, setS) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FilterSectionTitle('Status'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chip('Dalam Proses', selected: temp.status == ServiceFilter.active, onTap: () => setS(() => temp = temp.copyWith(status: ServiceFilter.active))),
                        _chip('Selesai', selected: temp.status == ServiceFilter.done, onTap: () => setS(() => temp = temp.copyWith(status: ServiceFilter.done))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _FilterSectionTitle('Urutkan'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chip('Terbaru', selected: temp.sort == ServiceSort.newest, onTap: () => setS(() => temp = temp.copyWith(sort: ServiceSort.newest))),
                        _chip('Nama A-Z', selected: temp.sort == ServiceSort.nameAZ, onTap: () => setS(() => temp = temp.copyWith(sort: ServiceSort.nameAZ))),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      );

      if (applied != null && mounted) setState(() => _serviceUiFilter = applied);
      return;
    }

    final items = currentList;
    final minQ = _minQty(items);
    final maxQ = _maxQty(items);

    _itemFilter ??= ItemFilterState.initial(minQty: minQ, maxQty: maxQ);

    final applied = await showModalBottomSheet<ItemFilterState>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        ItemFilterState temp = _itemFilter!.copyWith(
          qtyRange: RangeValues(
            _itemFilter!.qtyRange.start.clamp(minQ, maxQ),
            _itemFilter!.qtyRange.end.clamp(minQ, (maxQ == minQ ? (minQ + 1) : maxQ)),
          ),
        );

        final categories = items.map((e) => e.category).toSet().toList()..sort();
        final safeMax = maxQ == minQ ? (minQ + 1) : maxQ;

        return _FilterSheetContainer(
          title: 'Filter Barang',
          onClear: () => Navigator.of(ctx).pop(ItemFilterState.initial(minQty: minQ, maxQty: safeMax)),
          onApply: () => Navigator.of(ctx).pop(temp),
          child: StatefulBuilder(
            builder: (ctx, setS) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: temp.inStockOnly,
                    activeColor: kOrange,
                    title: const Text('Hanya stok tersedia', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Sembunyikan qty = 0', style: TextStyle(fontSize: 12)),
                    onChanged: (v) => setS(() => temp = temp.copyWith(inStockOnly: v)),
                  ),
                  const SizedBox(height: 10),
                  const _FilterSectionTitle('Kategori'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: categories.map((cat) {
                      final selected = temp.categories.contains(cat);
                      return _chip(
                        cat,
                        selected: selected,
                        onTap: () {
                          final next = Set<String>.from(temp.categories);
                          if (selected) {
                            next.remove(cat);
                          } else {
                            next.add(cat);
                          }
                          setS(() => temp = temp.copyWith(categories: next));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const _FilterSectionTitle('Range Qty'),
                  Text('${temp.qtyRange.start.toInt()} — ${temp.qtyRange.end.toInt()}',
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                  RangeSlider(
                    values: temp.qtyRange,
                    min: minQ,
                    max: safeMax,
                    divisions: ((safeMax - minQ).abs() < 1) ? 1 : (safeMax - minQ).round().clamp(1, 200),
                    activeColor: kOrange,
                    inactiveColor: Colors.black12,
                    onChanged: (v) => setS(() => temp = temp.copyWith(qtyRange: v)),
                  ),
                  const SizedBox(height: 6),
                  const _FilterSectionTitle('Urutkan'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _chip('Terbaru', selected: temp.sort == ItemSort.newest, onTap: () => setS(() => temp = temp.copyWith(sort: ItemSort.newest))),
                      _chip('Nama A-Z', selected: temp.sort == ItemSort.nameAZ, onTap: () => setS(() => temp = temp.copyWith(sort: ItemSort.nameAZ))),
                      _chip('Qty tertinggi', selected: temp.sort == ItemSort.qtyHigh, onTap: () => setS(() => temp = temp.copyWith(sort: ItemSort.qtyHigh))),
                      _chip('Qty terendah', selected: temp.sort == ItemSort.qtyLow, onTap: () => setS(() => temp = temp.copyWith(sort: ItemSort.qtyLow))),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (applied != null && mounted) setState(() => _itemFilter = applied);
  }

  Future<void> _showDetailBottomSheet(ItemModel item, {required bool isService}) async {
    Map<String, dynamic>? row;
    if (isService) {
      row = await _serviceService.getServiceRowById(item.id);
    } else {
      row = await _itemService.getItemRowById(item.id);
    }

    if (row == null) {
      if (mounted) _showSnack('Data detail tidak ditemukan di database', success: false);
      return;
    }

    final data = row;
    final String? imageUrl = data['image_url']?.toString();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        return _GlassBottomSheet(
          title: isService ? 'Detail Service' : 'Detail Barang',
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 14,
              bottom: 14 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          imageUrl,
                          width: 260,
                          height: 260,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imageFallback(isService),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Center(child: _imageFallback(isService)),
                    const SizedBox(height: 14),
                  ],
                  _glassDetailRow('ID', data['id']?.toString() ?? '-'),
                  _glassDetailRow('Nama', data['name']?.toString() ?? '-'),
                  if (isService) _glassDetailRow('Customer', data['customer']?.toString() ?? '-'),
                  if (isService) _glassDetailRow('No. Seri / IMEI', data['sku']?.toString() ?? '-'),
                  if (!isService) _glassDetailRow('Supplier', data['supplier']?.toString() ?? '-'),
                  _glassDetailRow('Kategori', data['category']?.toString() ?? '-'),
                  if (!isService) _glassDetailRow('Kondisi', data['condition']?.toString() ?? '-'),
                  if (data['harga'] != null) _glassDetailRow('Harga / Biaya', data['harga'].toString()),
                  if (isService) _glassDetailRow('Status', data['status']?.toString() ?? '-'),
                  _glassDetailRow('Qty', data['total']?.toString() ?? '-'),
                  if (data['date'] != null) _glassDetailRow('Tanggal', data['date'].toString()),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ModernButton(
                          text: 'Tutup',
                          color: Colors.white.withOpacity(0.08),
                          textColor: Colors.white,
                          onTap: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (!isService)
                        Expanded(
                          child: _ModernButton(
                            text: 'Keluarkan Stok',
                            color: kRed,
                            textColor: Colors.white,
                            icon: Icons.exit_to_app_rounded,
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              await Future.delayed(const Duration(milliseconds: 220));
                              if (!mounted) return;
                              await _showStockOutDialog(item);
                            },
                          ),
                        ),
                      if (isService)
                        Expanded(
                          child: _ModernButton(
                            text: 'Tandai Selesai',
                            color: kGreen,
                            textColor: Colors.white,
                            icon: Icons.check_circle_rounded,
                            onTap: () async {
                              final ok = await _serviceService.updateServiceRemote(item.id, status: 'Selesai');
                              if (!mounted) return;

                              if (ok) {
                                await _serviceService.loadServices();
                                await _stockOutService.loadTotalOut();
                                _showSnack('Service ditandai selesai', success: true);
                                Navigator.of(ctx).pop();
                              } else {
                                _showSnack('Gagal mengubah status service', success: false);
                              }
                            },
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
  }

  Widget _imageFallback(bool isService) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Icon(isService ? Icons.build_rounded : Icons.inventory_2_rounded, color: Colors.white.withOpacity(0.75), size: 44),
    );
  }

  Widget _glassDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.8, color: Color(0xFFC9D3E6))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.8, color: Colors.white))),
        ],
      ),
    );
  }

  void _showSnack(String message, {required bool success}) {
    final bg = success ? kGreen : kRed;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6))],
            ),
            child: Row(
              children: [
                Icon(success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = (user?.userMetadata?['full_name'] ?? '').toString().trim();
    final fallbackName = (user?.email ?? '').split('@').first.trim();
    final greetingName = fullName.isNotEmpty ? fullName : (fallbackName.isNotEmpty ? fallbackName : 'Pengguna');

    return Scaffold(
      backgroundColor: kHomeBg,
      body: SafeArea(
        child: ValueListenableBuilder<List<ItemModel>>(
          valueListenable: _itemService.items,
          builder: (context, items, _) {
            return ValueListenableBuilder<List<ItemModel>>(
              valueListenable: _serviceService.services,
              builder: (context, services, __) {
                if (_itemFilter == null && items.isNotEmpty) {
                  _itemFilter = ItemFilterState.initial(minQty: _minQty(items), maxQty: _maxQty(items));
                }

                final activeItems = items.where((e) => e.quantity > 0).toList();
                final totalStok = activeItems.fold<int>(0, (sum, e) => sum + e.quantity);

                final activeServices = services.where((s) => !s.category.toLowerCase().contains('(selesai)')).toList();
                final totalPerbaikanAktif = activeServices.length;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: _HeaderModern(greetingName: greetingName, onNotifications: _openNotifications, onProfile: _openProfile),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _SearchModern(
                          controller: _searchCtrl,
                          hint: 'Cari barang / service...',
                          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                          onClear: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Total Stok',
                                value: '$totalStok',
                                accent: kOrange,
                                icon: Icons.inventory_2_rounded,
                                selected: !_showServices,
                                onTap: () => setState(() => _showServices = false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'Perbaikan Aktif',
                                value: '$totalPerbaikanAktif',
                                accent: kGrayActive,
                                icon: Icons.build_circle_rounded,
                                selected: _showServices,
                                onTap: () => setState(() {
                                  _showServices = true;
                                  _serviceUiFilter = _serviceUiFilter.copyWith(status: ServiceFilter.active);
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ValueListenableBuilder<int>(
                                valueListenable: _stockOutService.totalOut,
                                builder: (context, totalOut, __) {
                                  return _StatCard(
                                    label: 'Data Keluar',
                                    value: '$totalOut',
                                    accent: kRed,
                                    icon: Icons.exit_to_app_rounded,
                                    selected: false,
                                    onTap: _openStockOutHistory,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _showServices ? 'Daftar Perbaikan' : 'Daftar Barang',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kDark),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final list = _showServices ? services : items;
                                await _openFilterSheet(list);
                              },
                              child: Ink(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: kLine),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.tune_rounded, size: 18, color: Colors.black54),
                                    SizedBox(width: 8),
                                    Text('Filter', style: TextStyle(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _showServices
                              ? _ActiveServiceFilterBar(state: _serviceUiFilter)
                              : (_itemFilter == null ? const SizedBox.shrink() : _ActiveItemFilterBar(filter: _itemFilter!)),
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _ListArea(
                          showServices: _showServices,
                          items: items,
                          services: services,
                          searchQuery: _searchQuery,
                          itemFilter: _itemFilter,
                          applyItemFilter: (list) => _applyItemFilter(list),
                          applyServiceFilter: (list) => _applyServiceFilter(list),
                          onRefresh: () async {
                            if (_showServices) {
                              await _serviceService.loadServices();
                            } else {
                              await _itemService.loadItems();
                            }
                            await _stockOutService.loadTotalOut();
                          },
                          onTapItem: (it) => _showDetailBottomSheet(it, isService: _showServices),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        onHomeTap: () => setState(() => _showServices = false),
        onAddTap: () => _showAddPopup(context),
        onSettingsTap: _openSettings,
        onProfileTap: _openProfile,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _CenterQrButton(onTap: _onScanQrTap),
    );
  }
}

// ====== BAGIAN WIDGET SUPPORT (SAMA PERSIS) ======
class _ListArea extends StatelessWidget {
  const _ListArea({
    required this.showServices,
    required this.items,
    required this.services,
    required this.searchQuery,
    required this.itemFilter,
    required this.applyItemFilter,
    required this.applyServiceFilter,
    required this.onRefresh,
    required this.onTapItem,
  });

  final bool showServices;
  final List<ItemModel> items;
  final List<ItemModel> services;
  final String searchQuery;

  final ItemFilterState? itemFilter;
  final List<ItemModel> Function(List<ItemModel>) applyItemFilter;
  final List<ItemModel> Function(List<ItemModel>) applyServiceFilter;

  final Future<void> Function() onRefresh;
  final void Function(ItemModel) onTapItem;

  @override
  Widget build(BuildContext context) {
    List<ItemModel> base = List<ItemModel>.from(showServices ? services : items);
    base = showServices ? applyServiceFilter(base) : applyItemFilter(base);

    final k = searchQuery.trim().toLowerCase();
    final filtered = base.where((it) {
      if (k.isEmpty) return true;
      return it.name.toLowerCase().contains(k) || it.category.toLowerCase().contains(k);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(showServices ? Icons.build_circle_outlined : Icons.inventory_2_outlined, size: 64, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 10),
            Text('Data tidak ditemukan', style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(showServices ? 'Ubah filter atau coba kata kunci lain.' : 'Tarik ke bawah untuk refresh data.',
                style: TextStyle(color: Colors.black.withOpacity(0.45))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kOrange,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 92),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: _InventoryListCard(item: item, isService: showServices, onTap: () => onTapItem(item)),
          );
        },
      ),
    );
  }
}

class _HeaderModern extends StatelessWidget {
  const _HeaderModern({
    required this.greetingName,
    required this.onNotifications,
    required this.onProfile,
  });

  final String greetingName;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kOrange.withOpacity(0.14), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLine),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kOrange.withOpacity(0.18)),
            ),
            child: const Icon(Icons.warehouse_rounded, color: kOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, $greetingName', style: const TextStyle(fontSize: 12.6, color: Colors.black54)),
                const SizedBox(height: 3),
                const Text('Gudang Utama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kDark)),
              ],
            ),
          ),
          _SquareIconButton(icon: Icons.notifications_none_rounded, onTap: onNotifications),
          const SizedBox(width: 10),
          _SquareIconButton(icon: Icons.person_rounded, onTap: onProfile),
        ],
      ),
    );
  }
}

class _SearchModern extends StatelessWidget {
  const _SearchModern({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.black38), border: InputBorder.none),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, v, _) {
              final has = v.text.trim().isNotEmpty;
              if (!has) return const SizedBox.shrink();
              return IconButton(onPressed: onClear, tooltip: 'Clear', icon: const Icon(Icons.close_rounded, color: Colors.black54), splashRadius: 18);
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool selected;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 90,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 8))],
        border: selected ? Border.all(color: Colors.white.withOpacity(0.85), width: 1.4) : Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const Spacer(),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: card));
  }
}

class _InventoryListCard extends StatelessWidget {
  final ItemModel item;
  final bool isService;
  final VoidCallback onTap;

  const _InventoryListCard({
    required this.item,
    required this.isService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;

    Widget leading;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(),
        ),
      );
    } else {
      leading = _fallbackIcon();
    }

    Widget? statusBadge;
    if (isService) {
      final lower = item.category.toLowerCase();
      final isDone = lower.contains('(selesai)');
      final label = isDone ? 'Selesai' : 'Dalam Proses';
      final color = isDone ? kGreen : const Color(0xFFF59E0B);

      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kLine),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 14.2)),
                    const SizedBox(height: 3),
                    Text(item.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.black.withOpacity(0.06)),
                          ),
                          child: Text('Qty: ${item.quantity}',
                              style: const TextStyle(color: Colors.black54, fontSize: 11.5, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        if (statusBadge != null) statusBadge,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kOrange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kOrange.withOpacity(0.18)),
                ),
                child: const Icon(Icons.chevron_right_rounded, color: kOrange, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Icon(isService ? Icons.build_rounded : Icons.inventory_2_rounded, color: Colors.grey[700]),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onAddTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProfileTap;

  const _BottomNavBar({
    required this.onHomeTap,
    required this.onAddTap,
    required this.onSettingsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: kOrange,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, -2), blurRadius: 10)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Home', onTap: onHomeTap),
          _NavItem(icon: Icons.add_circle_rounded, label: 'Tambah', onTap: onAddTap),
          const SizedBox(width: 46),
          _NavItem(icon: Icons.settings_rounded, label: 'Pengaturan', onTap: onSettingsTap),
          _NavItem(icon: Icons.person_rounded, label: 'Profil', onTap: onProfileTap),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.2, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterQrButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CenterQrButton({required this.onTap});

  @override
  State<_CenterQrButton> createState() => _CenterQrButtonState();
}

class _CenterQrButtonState extends State<_CenterQrButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.96 : 1.0,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.9)),
            boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 8), blurRadius: 16)],
          ),
          child: const Icon(Icons.qr_code_scanner, size: 36, color: kOrange),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kLine),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.grey[700], size: 22),
        ),
      ),
    );
  }
}

InputDecoration _modernFieldDec({required String label, required String hint, String? errorText}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kOrange, width: 1.5)),
  );
}

Widget _chip(String text, {required bool selected, required VoidCallback onTap}) {
  return InkWell(
    borderRadius: BorderRadius.circular(999),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? kOrange.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? kOrange.withOpacity(0.6) : kLine),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.2, color: selected ? kOrange : Colors.black87)),
    ),
  );
}

class _FilterSheetContainer extends StatelessWidget {
  const _FilterSheetContainer({required this.title, required this.child, required this.onClear, required this.onApply});

  final String title;
  final Widget child;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kLine),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 10))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black.withOpacity(0.10), borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: kDark))),
                  TextButton(onPressed: onClear, child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: onApply,
                    child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900, color: kDark, fontSize: 13.5)),
    );
  }
}

class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kLine),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 10))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black.withOpacity(0.10), borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: accent.withOpacity(0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(0.18))),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: kDark)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12.2)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: kOrange.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: kOrange.withOpacity(0.16))),
      child: Row(
        children: [
          Icon(icon, color: kOrange),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: kDark))),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: accent.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: accent.withOpacity(0.18))),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: accent.withOpacity(0.16), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 13.8)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12.2)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, size: 26, color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassBottomSheet extends StatelessWidget {
  const _GlassBottomSheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: kGlassBase.withOpacity(0.82),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -6))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(width: 46, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), borderRadius: BorderRadius.circular(999))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.2))),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white.withOpacity(0.85),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernButton extends StatelessWidget {
  const _ModernButton({required this.text, required this.color, required this.textColor, required this.onTap, this.icon});
  final String text;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 46,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.10))),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: textColor),
                  const SizedBox(width: 8),
                ],
                Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 13.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveItemFilterBar extends StatelessWidget {
  const _ActiveItemFilterBar({required this.filter});
  final ItemFilterState filter;

  @override
  Widget build(BuildContext context) {
    final pills = <String>[];
    if (filter.inStockOnly) pills.add('Stok > 0');
    if (filter.categories.isNotEmpty) pills.add('Kategori: ${filter.categories.length}');
    pills.add('Qty ${filter.qtyRange.start.toInt()}-${filter.qtyRange.end.toInt()}');

    String sortLabel = 'Terbaru';
    switch (filter.sort) {
      case ItemSort.nameAZ:
        sortLabel = 'Nama A-Z';
        break;
      case ItemSort.qtyHigh:
        sortLabel = 'Qty tinggi';
        break;
      case ItemSort.qtyLow:
        sortLabel = 'Qty rendah';
        break;
      case ItemSort.newest:
      default:
        sortLabel = 'Terbaru';
    }
    pills.add('Sort: $sortLabel');

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: kOrange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kOrange.withOpacity(0.18)),
          ),
          child: Text(pills[i], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.8, color: Color(0xFFB45309))),
        ),
      ),
    );
  }
}

class _ActiveServiceFilterBar extends StatelessWidget {
  const _ActiveServiceFilterBar({required this.state});
  final ServiceFilterState state;

  @override
  Widget build(BuildContext context) {
    final status = state.status == ServiceFilter.active ? 'Dalam Proses' : 'Selesai';
    final sort = state.sort == ServiceSort.newest ? 'Terbaru' : 'Nama A-Z';

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _pill('Status: $status'),
          const SizedBox(width: 8),
          _pill('Sort: $sort'),
        ],
      ),
    );
  }

  Widget _pill(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.black.withOpacity(0.06))),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.8, color: Colors.black54)),
    );
  }
}
