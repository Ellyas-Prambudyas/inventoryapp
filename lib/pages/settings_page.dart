import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/user_settings_service.dart';

// Tema disamakan dengan dashboard
const Color kSettingsBg = Color(0xFFF5F5F5);
const Color kOrange = Color(0xFFFF7A00);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _userSettings = UserSettingsService();

  bool _loading = true;
  bool _saving = false;

  // Preferensi notifikasi
  bool _notifItemAdded = true;
  bool _notifServiceIn = true;
  bool _notifStockOut = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() => _loading = true);

    final prefs = await _userSettings.loadPrefs();
    if (!mounted) return;

    setState(() {
      _notifItemAdded = prefs.notifItemAdded;
      _notifServiceIn = prefs.notifServiceIn;
      _notifStockOut = prefs.notifStockOut;
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    final ok = await _userSettings.savePrefs(
      NotificationPrefs(
        notifItemAdded: _notifItemAdded,
        notifServiceIn: _notifServiceIn,
        notifStockOut: _notifStockOut,
      ),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? 'Pengaturan disimpan' : 'Gagal menyimpan pengaturan'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSettingsBg,
      appBar: AppBar(
        title: const Text('Pengaturan Notifikasi'),
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_rounded),
            onPressed: _saving ? null : _saveSettings,
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionCard(
                    title: 'Notifikasi',
                    children: [
                      SwitchListTile(
                        title: const Text('Barang baru ditambahkan'),
                        subtitle: const Text('Notifikasi saat barang masuk'),
                        value: _notifItemAdded,
                        onChanged: (v) => setState(() => _notifItemAdded = v),
                      ),
                      SwitchListTile(
                        title: const Text('Service masuk'),
                        subtitle: const Text('Notifikasi saat service diterima'),
                        value: _notifServiceIn,
                        onChanged: (v) => setState(() => _notifServiceIn = v),
                      ),
                      SwitchListTile(
                        title: const Text('Barang keluar'),
                        subtitle: const Text('Notifikasi saat stok dikurangi'),
                        value: _notifStockOut,
                        onChanged: (v) => setState(() => _notifStockOut = v),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_rounded),
                        title: const Text('Lihat Notifikasi'),
                        subtitle: const Text('Riwayat aktivitas barang dan service'),
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.notifications);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tekan ikon simpan di kanan atas untuk menyimpan preferensi notifikasi.',
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}
