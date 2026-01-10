import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  static const Color _orange = Color(0xFFFF7A00);
  static const Color _bg = Color(0xFFF5F6FA);

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  late final AnimationController _logoCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _ringFade;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOutCubic),
    );

    _ringFade = Tween<double>(begin: 0.20, end: 0.55).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    final fullName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showNotice(NoticeType.error, 'Daftar gagal', 'Email dan password wajib diisi.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showNotice(NoticeType.error, 'Daftar gagal', 'Format email tidak valid. Contoh: nama@email.com');
      return;
    }

    if (password.length < 6) {
      _showNotice(NoticeType.error, 'Daftar gagal', 'Password minimal 6 karakter.');
      return;
    }

    if (password != confirm) {
      _showNotice(NoticeType.error, 'Daftar gagal', 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (!mounted) return;

      // TANPA EMAIL VERIFIKASI
      _showNotice(
        NoticeType.success,
        'Akun berhasil dibuat',
        'Pendaftaran berhasil. Silakan login untuk melanjutkan.',
      );

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showNotice(NoticeType.error, 'Daftar gagal', _mapAuthError(e.message));
    } catch (_) {
      if (!mounted) return;
      _showNotice(NoticeType.error, 'Daftar gagal', 'Terjadi kesalahan sistem. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  String _mapAuthError(String raw) {
    final lower = raw.toLowerCase();

    // Ini muncul kalau Confirm Email masih ON atau SMTP bermasalah
    if (lower.contains('error sending confirmation email')) {
      return 'Supabase masih mencoba mengirim email. Matikan Confirm Email di Auth → Providers → Email.';
    }
    if (lower.contains('already registered') || lower.contains('user already')) {
      return 'Email sudah terdaftar. Silakan login.';
    }
    if (lower.contains('invalid email')) {
      return 'Format email tidak valid.';
    }
    if (lower.contains('password')) {
      return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Koneksi bermasalah. Periksa internet lalu coba lagi.';
    }

    return raw.isEmpty ? 'Pendaftaran gagal. Coba lagi.' : raw;
  }

  // NOTIFIKASI MODERN: SnackBar floating (tidak blur, tidak nutup layar)
  void _showNotice(NoticeType type, String title, String message) {
    final accent = type == NoticeType.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final icon = type == NoticeType.success ? Icons.check_circle_rounded : Icons.error_rounded;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 12,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: Duration(seconds: type == NoticeType.success ? 2 : 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withOpacity(0.18)),
        ),
        action: type == NoticeType.error
            ? SnackBarAction(
                label: 'Tutup',
                textColor: accent,
                onPressed: () => messenger.hideCurrentSnackBar(),
              )
            : null,
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.70),
                      fontSize: 12.8,
                      height: 1.25,
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

  InputDecoration _dec({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white, // tajam (tidak blur)
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _orange, width: 1.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background (tanpa blur filter)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    _orange.withOpacity(0.07),
                    const Color(0xFFEFF2F8),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: -90, right: -60, child: _GlowBlob(color: _orange.withOpacity(0.18), size: 260)),
          Positioned(bottom: -110, left: -70, child: _GlowBlob(color: Colors.black.withOpacity(0.06), size: 300)),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),

                      _PremiumLogo(
                        pulse: _pulse,
                        ringFade: _ringFade,
                        accent: _orange,
                        subtitle: 'Register',
                      ),

                      const SizedBox(height: 18),

                      // Card tajam (HAPUS BackdropFilter agar tidak blur)
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Buat Akun',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Daftar untuk mulai kelola inventory dan service secara rapi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black.withOpacity(0.58), height: 1.25),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: _dec(
                                label: 'Nama Lengkap (opsional)',
                                icon: Icons.badge_rounded,
                                hint: 'Contoh: Budi Santoso',
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _dec(
                                label: 'Email',
                                icon: Icons.email_rounded,
                                hint: 'nama@email.com',
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: _passwordCtrl,
                              obscureText: _obscure1,
                              textInputAction: TextInputAction.next,
                              decoration: _dec(
                                label: 'Password',
                                icon: Icons.lock_rounded,
                                hint: 'Minimal 6 karakter',
                                helper: 'Gunakan minimal 6 karakter',
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                                  icon: Icon(_obscure1 ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: _confirmCtrl,
                              obscureText: _obscure2,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (!_loading) _onRegister();
                              },
                              decoration: _dec(
                                label: 'Konfirmasi Password',
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                                  icon: Icon(_obscure2 ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Tombol NORMAL (tidak blur)
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _onRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _orange,
                                  disabledBackgroundColor: _orange.withOpacity(0.45),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_loading) ...[
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Text(
                                      _loading ? 'Memproses…' : 'Daftar',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Dengan mendaftar, Anda menyetujui kebijakan penggunaan aplikasi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.50), height: 1.25),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sudah punya akun? ', style: TextStyle(color: Colors.black.withOpacity(0.70))),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                            child: const Text('Login', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),

                      if (AuthService.session != null) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
                          child: const Text('Lanjutkan ke Dashboard'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum NoticeType { success, error }

class _PremiumLogo extends StatelessWidget {
  final Animation<double> pulse;
  final Animation<double> ringFade;
  final Color accent;
  final String subtitle;

  const _PremiumLogo({
    required this.pulse,
    required this.ringFade,
    required this.accent,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulse,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: ringFade,
                builder: (context, _) {
                  return Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withOpacity(ringFade.value),
                          accent.withOpacity(0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: accent.withOpacity(0.28), width: 1.2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 10)),
                  ],
                ),
                child: Icon(Icons.inventory_2_rounded, color: accent, size: 36),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Inventory App',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.2),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 20)],
      ),
    );
  }
}
