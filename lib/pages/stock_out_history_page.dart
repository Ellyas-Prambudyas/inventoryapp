import 'package:flutter/material.dart';

import '../models/stock_out_model.dart';
import '../services/stock_out_service.dart';

// Sama seperti HomePage
const Color kHomeBg = Color(0xFFF5F5F5);
const Color kOrange = Color(0xFFFF7A00);

class StockOutHistoryPage extends StatefulWidget {
  const StockOutHistoryPage({super.key});

  @override
  State<StockOutHistoryPage> createState() => _StockOutHistoryPageState();
}

class _StockOutHistoryPageState extends State<StockOutHistoryPage> {
  final _stockOutService = StockOutService();

  // ALL / ITEM / SERVICE
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _stockOutService.loadLogs();
    await _stockOutService.loadTotalOut();
  }

  // ================== HAPUS MASSAL (BOTTOM SHEET) ==================
  Future<void> _showDeleteAllSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Hapus Riwayat',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                // HAPUS SEMUA (ITEM + SERVICE)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                  ),
                  title: const Text('Hapus semua riwayat (ITEM + SERVICE)'),
                  onTap: () async {
                    Navigator.pop(ctx);

                    final ok = await _stockOutService.deleteAllLogs();
                    if (ok) {
                      await _stockOutService.refreshAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Semua riwayat (ITEM + SERVICE) dihapus'),
                          ),
                        );
                      }
                    }
                  },
                ),

                // HAPUS SEMUA ITEM SAJA
                ListTile(
                  leading: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    'Hapus semua riwayat Barang Baru (ITEM saja)',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);

                    final ok =
                        await _stockOutService.deleteAllLogs(refType: 'ITEM');
                    if (ok) {
                      await _stockOutService.refreshAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Semua riwayat Barang Baru (ITEM) dihapus'),
                          ),
                        );
                      }
                    }
                  },
                ),

                // HAPUS SEMUA SERVICE SAJA
                ListTile(
                  leading: const Icon(
                    Icons.build_rounded,
                    color: Colors.blue,
                  ),
                  title: const Text(
                    'Hapus semua riwayat Service (SERVICE saja)',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);

                    final ok = await _stockOutService
                        .deleteAllLogs(refType: 'SERVICE');
                    if (ok) {
                      await _stockOutService.refreshAll();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Semua riwayat Service (SERVICE) dihapus'),
                          ),
                        );
                      }
                    }
                  },
                ),

                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================== HAPUS SATU LOG (SWIPE) ==================
  Future<bool> _confirmDeleteOne(StockOutModel item) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Hapus Riwayat',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Text(
                'Yakin ingin menghapus log:\n\n${item.name ?? '-'} ?',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Hapus',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHomeBg,
      appBar: AppBar(
        backgroundColor: kHomeBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Riwayat Data Keluar',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _showDeleteAllSheet,
            tooltip: 'Hapus riwayat',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ===== FILTER TIPE =====
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FilterChip(
                    label: 'Semua',
                    value: 'ALL',
                    groupValue: _filter,
                    onChanged: (val) {
                      setState(() {
                        _filter = val;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Barang Baru',
                    value: 'ITEM',
                    groupValue: _filter,
                    onChanged: (val) {
                      setState(() {
                        _filter = val;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Service',
                    value: 'SERVICE',
                    groupValue: _filter,
                    onChanged: (val) {
                      setState(() {
                        _filter = val;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ===== TOTAL KELUAR =====
              ValueListenableBuilder<int>(
                valueListenable: _stockOutService.totalOut,
                builder: (context, totalOut, _) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total barang keluar: $totalOut',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // ===== LIST RIWAYAT =====
              Expanded(
                child: ValueListenableBuilder<List<StockOutModel>>(
                  valueListenable: _stockOutService.logs,
                  builder: (context, logs, _) {
                    final filtered = _filter == 'ALL'
                        ? logs
                        : logs
                            .where(
                              (e) =>
                                  (e.refType ?? '').toUpperCase() == _filter,
                            )
                            .toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada data keluar.',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _stockOutService.refreshAll,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];

                          final key = ValueKey(
                            item.id ??
                                '${item.refId}_${item.createdAt?.toIso8601String()}_$index',
                          );

                          return Dismissible(
                            key: key,
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDeleteOne(item),
                            onDismissed: (_) async {
                              final id = item.id;
                              if (id == null || id.isEmpty) {
                                // kalau tidak ada ID, reload saja dari server
                                await _stockOutService.refreshAll();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Log ini tidak punya ID, tidak bisa dihapus.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              final ok =
                                  await _stockOutService.deleteOut(id);
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Gagal menghapus riwayat di server',
                                    ),
                                  ),
                                );
                              } else {
                                // pastikan sinkron dengan server
                                await _stockOutService.refreshAll();
                              }
                            },
                            background: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                              ),
                            ),
                            child: _StockOutCard(item: item),
                          );
                        },
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
//  WIDGET KECIL: FILTER CHIP
// =====================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = value == groupValue;

    return ChoiceChip(
      selected: selected,
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      selectedColor: kOrange,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? kOrange : Colors.grey.shade300,
      ),
      onSelected: (_) => onChanged(value),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// =====================================================
//  WIDGET KARTU RIWAYAT STOCK OUT
// =====================================================

class _StockOutCard extends StatelessWidget {
  final StockOutModel item;

  const _StockOutCard({required this.item});

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final String type =
        (item.refType ?? '').toUpperCase() == 'SERVICE' ? 'SERVICE' : 'ITEM';
    final bool isService = type == 'SERVICE';
    final typeColor = isService ? Colors.blueAccent : Colors.green;

    final String name = item.name ?? '-';
    final String? note = item.note;
    final DateTime createdAt =
        item.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isService ? Icons.build_rounded : Icons.inventory_2_rounded,
              color: typeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty keluar: ${item.quantity}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
