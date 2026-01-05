import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_routes.dart';
import '../services/profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Theme
  static const Color _bg = Color(0xFFF5F6FA);
  static const Color _card = Colors.white;
  static const Color _orange = Color(0xFFFF7A00);
  static const Color _text = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _warehouseCtrl = TextEditingController();

  String? _avatarUrl;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _warehouseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final p = await _profileService.load();
      if (!mounted) return;

      _nameCtrl.text = p.fullName;
      _emailCtrl.text = p.email;
      _warehouseCtrl.text = p.warehouse;
      _avatarUrl = p.avatarUrl;
    } catch (_) {
      // Biarkan kosong jika belum login / gagal load
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final ok = await _profileService.update(
      fullName: _nameCtrl.text.trim(),
      warehouse: _warehouseCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(ok ? 'Profil berhasil diperbarui' : 'Gagal memperbarui profil'),
        ),
      );

    if (ok) await _load();
  }

  Future<void> _logout() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return const _ConfirmSheet(
          title: 'Keluar dari akun?',
          message: 'Anda akan kembali ke halaman login.',
          confirmText: 'Logout',
          confirmColor: Colors.redAccent,
        );
      },
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal logout. Coba lagi.'),
          ),
        );
    }
  }

  String _initials(String nameOrEmail) {
    final raw = nameOrEmail.trim();
    if (raw.isEmpty) return 'U';
    final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
    return raw.substring(0, 1).toUpperCase();
  }

  Future<void> _pickAndUploadAvatar() async {
    // Pilih sumber foto (galeri / kamera)
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ActionSheet(
          title: 'Upload Foto Profil',
          subtitle: 'Pilih sumber foto',
          actions: [
            _ActionTile(
              icon: Icons.photo_library_rounded,
              title: 'Dari Galeri',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _ActionTile(
              icon: Icons.photo_camera_rounded,
              title: 'Dari Kamera',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        );
      },
    );

    if (source == null) return;

    try {
      setState(() => _uploadingAvatar = true);

      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // kompres ringan supaya upload cepat
        maxWidth: 1024,
      );

      if (xfile == null) {
        if (mounted) setState(() => _uploadingAvatar = false);
        return;
      }

      final file = File(xfile.path);
      final url = await _profileService.uploadAvatar(file);

      if (!mounted) return;

      setState(() {
        _avatarUrl = url;
        _uploadingAvatar = false;
      });

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(url != null ? 'Foto profil berhasil diperbarui' : 'Gagal upload foto profil'),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal mengambil / upload foto.'),
          ),
        );
    }
  }

  Future<void> _changePassword() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );

    if (result != true) return;

    // password sudah diubah di sheet (kalau true)
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Password berhasil diperbarui'),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x1A000000)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x1A000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _orange, width: 1.8),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x14000000)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 18,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Pengguna';
    final email = _emailCtrl.text.trim();
    final warehouse = _warehouseCtrl.text.trim();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Background accent
                  Positioned(
                    left: -120,
                    top: -140,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _orange.withOpacity(0.10),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -140,
                    top: 60,
                    child: Container(
                      width: 340,
                      height: 340,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _orange.withOpacity(0.06),
                      ),
                    ),
                  ),

                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.white,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        title: const Text(
                          'Profil',
                          style: TextStyle(fontWeight: FontWeight.w900, color: _text),
                        ),
                        centerTitle: true,
                        actions: [
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded, color: _text),
                          ),
                          IconButton(
                            tooltip: 'Logout',
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded, color: _text),
                          ),
                          const SizedBox(width: 6),
                        ],
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(1),
                          child: Container(height: 1, color: Colors.black12),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ===== Header Card =====
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: _cardDecoration(),
                                    child: Row(
                                      children: [
                                        _AvatarBadge(
                                          accent: _orange,
                                          initials: _initials(
                                            displayName != 'Pengguna' ? displayName : (email.isNotEmpty ? email : 'U'),
                                          ),
                                          avatarUrl: _avatarUrl,
                                          uploading: _uploadingAvatar,
                                          onTapUpload: _pickAndUploadAvatar,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: _text,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                email.isNotEmpty ? email : 'Email belum terdeteksi',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: _muted,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (warehouse.isNotEmpty)
                                                    _InfoPill(
                                                      icon: Icons.warehouse_rounded,
                                                      text: warehouse,
                                                      accent: _orange,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // ===== Form =====
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                                    decoration: _cardDecoration(),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          const _SectionTitle(
                                            title: 'Informasi Profil',
                                            subtitle: 'Nama dan gudang akan tampil di aplikasi.',
                                          ),
                                          const SizedBox(height: 14),

                                          TextFormField(
                                            controller: _nameCtrl,
                                            decoration: _inputDecoration(
                                              label: 'Nama',
                                              hint: 'Masukkan nama Anda',
                                              icon: Icons.badge_rounded,
                                            ),
                                            validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                                            onChanged: (_) => setState(() {}),
                                            textInputAction: TextInputAction.next,
                                          ),
                                          const SizedBox(height: 12),

                                          TextFormField(
                                            controller: _emailCtrl,
                                            readOnly: true,
                                            decoration: _inputDecoration(
                                              label: 'Email',
                                              icon: Icons.email_rounded,
                                              readOnly: true,
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          TextFormField(
                                            controller: _warehouseCtrl,
                                            decoration: _inputDecoration(
                                              label: 'Gudang / Posisi',
                                              hint: 'Contoh: Gudang Utama',
                                              icon: Icons.warehouse_rounded,
                                            ),
                                            onChanged: (_) => setState(() {}),
                                            textInputAction: TextInputAction.done,
                                          ),

                                          const SizedBox(height: 14),

                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: const Color(0x14000000)),
                                            ),
                                            child: Row(
                                              children: const [
                                                Icon(Icons.info_outline_rounded, color: _muted),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    'Email bersifat read-only. Upload foto tersimpan per akun login (UID).',
                                                    style: TextStyle(
                                                      color: _muted,
                                                      fontWeight: FontWeight.w600,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // ===== Security =====
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: _cardDecoration(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const _SectionTitle(
                                          title: 'Keamanan',
                                          subtitle: 'Kelola password dan sesi login.',
                                        ),
                                        const SizedBox(height: 12),

                                        SizedBox(
                                          height: 48,
                                          child: OutlinedButton.icon(
                                            onPressed: _changePassword,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _text,
                                              side: const BorderSide(color: Color(0x22000000)),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: const Icon(Icons.lock_reset_rounded),
                                            label: const Text(
                                              'Ganti Password',
                                              style: TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 10),

                                        SizedBox(
                                          height: 48,
                                          child: OutlinedButton.icon(
                                            onPressed: _logout,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              side: const BorderSide(color: Colors.redAccent),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            icon: const Icon(Icons.logout_rounded),
                                            label: const Text(
                                              'Logout',
                                              style: TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ),
                                      ],
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

                  // ===== Sticky Bottom Actions =====
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: const Border(top: BorderSide(color: Colors.black12)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x11000000),
                              blurRadius: 18,
                              offset: Offset(0, -10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      onPressed: _saving ? null : _load,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _text,
                                        side: const BorderSide(color: Color(0x22000000)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text(
                                        'Muat Ulang',
                                        style: TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: _saving ? null : _save,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _orange,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.save_rounded),
                                      label: Text(
                                        _saving ? 'Menyimpan...' : 'Simpan',
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  final String initials;
  final Color accent;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onTapUpload;

  const _AvatarBadge({
    required this.initials,
    required this.accent,
    required this.avatarUrl,
    required this.uploading,
    required this.onTapUpload,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: uploading ? null : onTapUpload,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withOpacity(0.18),
                  accent.withOpacity(0.08),
                ],
              ),
              border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
              image: hasAvatar
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl!),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    )
                  : null,
            ),
            child: hasAvatar
                ? null
                : Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: uploading
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                : Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: accent,
                  ),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final Color confirmColor;

  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0x22000000)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Batal',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _ActionSheet({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: const Color(0xFFF8FAFC),
        leading: Icon(icon, color: const Color(0xFF0F172A)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        onTap: onTap,
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();

  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final ok = await _profileService.changePassword(_passCtrl.text);
    if (!mounted) return;

    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Gagal mengganti password. Coba login ulang lalu ulangi.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ganti Password',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure1,
                  decoration: InputDecoration(
                    labelText: 'Password baru',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                      icon: Icon(_obscure1 ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.length < 6) return 'Minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure2,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                      icon: Icon(_obscure2 ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '') != _passCtrl.text) return 'Konfirmasi tidak sama';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text(
                            'Simpan Password',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
