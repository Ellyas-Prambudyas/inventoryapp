import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/user_settings_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _supabase = Supabase.instance.client;
  final _userSettings = UserSettingsService();

  bool _loading = true;
  bool _prefsLoading = true;

  NotificationPrefs _prefs = const NotificationPrefs();
  List<_NotifItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadPrefsAndNotifications();
  }

  Future<void> _loadPrefsAndNotifications() async {
    setState(() => _prefsLoading = true);

    final prefs = await _userSettings.loadPrefs();
    if (!mounted) return;

    setState(() {
      _prefs = prefs;
      _prefsLoading = false;
    });

    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);

    try {
      // ITEMS
      final itemsRes = _prefs.notifItemAdded
          ? await _supabase
              .from('items')
              .select('id, name, category, total, created_at')
              .order('created_at', ascending: false)
              .limit(20)
          : const [];

      // SERVICES
      final servicesRes = _prefs.notifServiceIn
          ? await _supabase
              .from('services')
              .select('id, name, category, status, total, created_at')
              .order('created_at', ascending: false)
              .limit(20)
          : const [];

      // STOCK OUT (WAJIB ambil ref_id biar detail lebih lengkap)
      final stockOutRes = _prefs.notifStockOut
          ? await _supabase
              .from('stock_out')
              .select('id, name, ref_type, ref_id, quantity, note, created_at')
              .order('created_at', ascending: false)
              .limit(20)
          : const [];

      final List<_NotifItem> notifItems = [];

      // Mapping items → notifikasi
      for (final row in (itemsRes as List)) {
        final map = row as Map<String, dynamic>;
        final createdAt =
            DateTime.tryParse((map['created_at'] ?? '').toString()) ??
                DateTime.now();

        final name = (map['name'] ?? '').toString();
        final category = (map['category'] ?? '').toString();
        final total = map['total']?.toString() ?? '-';

        notifItems.add(
          _NotifItem(
            id: map['id'].toString(),
            createdAt: createdAt,
            title: 'Barang baru ditambahkan',
            subtitle: '$name • $category • Qty: $total',
            type: NotifType.item,
          ),
        );
      }

      // Mapping services → notifikasi
      for (final row in (servicesRes as List)) {
        final map = row as Map<String, dynamic>;
        final createdAt =
            DateTime.tryParse((map['created_at'] ?? '').toString()) ??
                DateTime.now();

        final name = (map['name'] ?? '').toString();
        final category = (map['category'] ?? '').toString();
        final status = (map['status'] ?? '').toString();
        final total = map['total']?.toString() ?? '-';

        notifItems.add(
          _NotifItem(
            id: map['id'].toString(),
            createdAt: createdAt,
            title: 'Service masuk',
            subtitle: '$name • $category • Status: $status • Qty: $total',
            type: NotifType.service,
          ),
        );
      }

      // Mapping stock_out → notifikasi
      for (final row in (stockOutRes as List)) {
        final map = row as Map<String, dynamic>;
        final createdAt =
            DateTime.tryParse((map['created_at'] ?? '').toString()) ??
                DateTime.now();

        final name = (map['name'] ?? '').toString();
        final refType = (map['ref_type'] ?? '').toString();
        final refId = map['ref_id']?.toString();
        final qty = map['quantity']?.toString() ?? '-';
        final note = (map['note'] ?? '').toString().trim();

        notifItems.add(
          _NotifItem(
            id: map['id'].toString(), // id stock_out
            createdAt: createdAt,
            title: 'Barang keluar',
            subtitle:
                '$name • $refType${refId != null && refId.isNotEmpty ? ' • Ref: $refId' : ''} • Qty: $qty${note.isNotEmpty ? ' • $note' : ''}',
            type: NotifType.stockOut,
            refType: refType,
            refId: refId,
          ),
        );
      }

      // sort berdasarkan createdAt (desc)
      notifItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() => _items = notifItems);
    } catch (e, st) {
      debugPrint('Gagal load notifikasi: $e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat notifikasi')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchMainDetail(_NotifItem n) async {
    try {
      if (n.type == NotifType.item) {
        return await _supabase
            .from('items')
            .select('*')
            .eq('id', n.id)
            .maybeSingle();
      }

      if (n.type == NotifType.service) {
        return await _supabase
            .from('services')
            .select('*')
            .eq('id', n.id)
            .maybeSingle();
      }

      // stock_out
      return await _supabase
          .from('stock_out')
          .select('*')
          .eq('id', n.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchRefDetail(_NotifItem n) async {
    try {
      if (n.type != NotifType.stockOut) return null;
      final refId = (n.refId ?? '').trim();
      final refType = (n.refType ?? '').trim().toUpperCase();
      if (refId.isEmpty || refType.isEmpty) return null;

      if (refType == 'ITEM') {
        return await _supabase
            .from('items')
            .select('*')
            .eq('id', refId)
            .maybeSingle();
      }

      if (refType == 'SERVICE') {
        return await _supabase
            .from('services')
            .select('*')
            .eq('id', refId)
            .maybeSingle();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  void _openNotifDetail(_NotifItem n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) {
        return _NotifDetailSheet(
          item: n,
          loadMain: () => _fetchMainDetail(n),
          loadRef: () => _fetchRefDetail(n),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    const bg = Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black12),
        ),
      ),
      body: RefreshIndicator(
        color: orange,
        onRefresh: _loadPrefsAndNotifications,
        child: (_prefsLoading || _loading)
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: const [
                      SizedBox(height: 70),
                      _EmptyNotifState(),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final n = _items[index];
                      return _NotifTile(
                        item: n,
                        onTap: () => _openNotifDetail(n),
                      );
                    },
                  ),
      ),
    );
  }
}

// ==================== EMPTY STATE ====================

class _EmptyNotifState extends StatelessWidget {
  const _EmptyNotifState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: const [
          Icon(Icons.notifications_none_rounded,
              size: 44, color: Colors.black54),
          SizedBox(height: 10),
          Text(
            'Belum ada aktivitas',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Aktifkan jenis notifikasi di Pengaturan atau tambah data untuk melihat riwayat di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// ==================== MODEL NOTIFIKASI ====================

enum NotifType { item, service, stockOut }

class _NotifItem {
  final String id;
  final DateTime createdAt;
  final String title;
  final String subtitle;
  final NotifType type;

  // khusus stock_out (optional)
  final String? refType;
  final String? refId;

  _NotifItem({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.subtitle,
    required this.type,
    this.refType,
    this.refId,
  });
}

// ==================== TILE ====================

class _NotifTile extends StatelessWidget {
  final _NotifItem item;
  final VoidCallback? onTap;

  const _NotifTile({
    required this.item,
    this.onTap,
  });

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    // Selaraskan dengan tema Home: item=green, service=purple, keluar=red
    const kGreen = Color(0xFF22C55E);
    const kPurple = Color(0xFF7C3AED);
    const kRed = Color(0xFFEF4444);

    final isService = item.type == NotifType.service;
    final isStockOut = item.type == NotifType.stockOut;

    final icon = isStockOut
        ? Icons.exit_to_app_rounded
        : (isService ? Icons.build_circle_rounded : Icons.inventory_2_rounded);

    final color = isStockOut ? kRed : (isService ? kPurple : kGreen);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black38),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(item.subtitle, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              _formatDate(item.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== DETAIL BOTTOM SHEET ====================

class _NotifDetailSheet extends StatelessWidget {
  final _NotifItem item;
  final Future<Map<String, dynamic>?> Function() loadMain;
  final Future<Map<String, dynamic>?> Function() loadRef;

  const _NotifDetailSheet({
    required this.item,
    required this.loadMain,
    required this.loadRef,
  });

  @override
  Widget build(BuildContext context) {
    const kOrange = Color(0xFFFF7A00);
    const kGreen = Color(0xFF22C55E);
    const kPurple = Color(0xFF7C3AED);
    const kRed = Color(0xFFEF4444);

    final isService = item.type == NotifType.service;
    final isStockOut = item.type == NotifType.stockOut;

    final icon = isStockOut
        ? Icons.exit_to_app_rounded
        : (isService ? Icons.build_circle_rounded : Icons.inventory_2_rounded);

    final color = isStockOut ? kRed : (isService ? kPurple : kGreen);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          margin: const EdgeInsets.only(top: 80),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.12),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 12.2,
                              color: Colors.black54,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      splashRadius: 20,
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                FutureBuilder<Map<String, dynamic>?>(
                  future: loadMain(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: CircularProgressIndicator(),
                      );
                    }

                    final data = snap.data;
                    if (data == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Detail tidak ditemukan di database.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detail',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),

                        _kv('ID', data['id']?.toString() ?? '-'),
                        _kv('Nama', data['name']?.toString() ?? '-'),

                        if (item.type == NotifType.item) ...[
                          _kv('Kategori', data['category']?.toString() ?? '-'),
                          _kv('Qty', data['total']?.toString() ?? '-'),
                          if (data['supplier'] != null)
                            _kv('Supplier', data['supplier']?.toString() ?? '-'),
                          if (data['condition'] != null)
                            _kv('Kondisi', data['condition']?.toString() ?? '-'),
                          if (data['harga'] != null)
                            _kv('Harga', data['harga']?.toString() ?? '-'),
                        ],

                        if (item.type == NotifType.service) ...[
                          _kv('Kategori', data['category']?.toString() ?? '-'),
                          _kv('Status', data['status']?.toString() ?? '-'),
                          _kv('Qty', data['total']?.toString() ?? '-'),
                          if (data['customer'] != null)
                            _kv('Customer', data['customer']?.toString() ?? '-'),
                          if (data['sku'] != null)
                            _kv('SKU/IMEI', data['sku']?.toString() ?? '-'),
                          if (data['harga'] != null)
                            _kv('Biaya', data['harga']?.toString() ?? '-'),
                        ],

                        if (item.type == NotifType.stockOut) ...[
                          _kv('Ref Type', data['ref_type']?.toString() ?? '-'),
                          if (data['ref_id'] != null)
                            _kv('Ref ID', data['ref_id']?.toString() ?? '-'),
                          _kv('Qty Keluar', data['quantity']?.toString() ?? '-'),
                          if ((data['note'] ?? '').toString().trim().isNotEmpty)
                            _kv('Catatan', data['note']?.toString() ?? '-'),
                        ],

                        if (data['created_at'] != null)
                          _kv('Waktu', data['created_at']?.toString() ?? '-'),

                        if (isStockOut) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          const Text(
                            'Referensi',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: loadRef(),
                            builder: (context, refSnap) {
                              if (refSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: LinearProgressIndicator(minHeight: 3),
                                );
                              }
                              final ref = refSnap.data;
                              if (ref == null) {
                                return const Text(
                                  'Data referensi tidak ditemukan (mungkin sudah dihapus).',
                                  style: TextStyle(color: Colors.black54, fontSize: 12.2),
                                );
                              }

                              // Ringkas tapi informatif
                              final refName = ref['name']?.toString() ?? '-';
                              final refCat = ref['category']?.toString() ?? '-';
                              final refQty = (ref['total'] ?? ref['quantity'])?.toString() ?? '-';
                              final refStatus = ref['status']?.toString();

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      refName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$refCat • Qty: $refQty${refStatus != null && refStatus.isNotEmpty ? ' • Status: $refStatus' : ''}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12.2,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Tutup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 12.4,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
