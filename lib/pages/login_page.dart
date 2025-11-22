import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../routes/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  static const String _validUsername = 'admin';
  static const String _validPassword = 'admin123';

  final String _adminPhone = '6281234567890';

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _onLogin() {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showLoginPopup(
        title: 'LOGIN GAGAL',
        message: 'Username dan password wajib diisi',
        success: false,
      );
      return;
    }

    if (username == _validUsername && password == _validPassword) {
      _showLoginPopup(
        title: 'LOGIN BERHASIL',
        message: 'Selamat datang di Inventory App',
        success: true,
      );

      // pindah ke homepage setelah popup hilang
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    } else {
      _showLoginPopup(
        title: 'LOGIN GAGAL',
        message: 'Username atau password salah',
        success: false,
      );
    }
  }

  Future<void> _hubungiAdmin() async {
    final uri = Uri.parse(
      'https://wa.me/$_adminPhone?text='
      'Halo%20admin,%20saya%20tidak%20bisa%20login%20ke%20Inventory%20App.',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp')),
      );
    }
  }

  void _showLoginPopup({
    required String title,
    required String message,
    required bool success,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 220),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: 260,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: success ? const Color(0xFFF28B3A) : Colors.redAccent,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.error,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'INVENTORY APP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(
                    color: Colors.white70,
                    thickness: 1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF28B3A); // warna header, field, tombol
    const yellow = Color(0xFFFFF3A3); // warna background

    return Scaffold(
      backgroundColor: yellow,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== HEADER ORANYE =====
          Container(
            height: 80,
            color: orange,
            alignment: Alignment.center,
            child: const Text(
              'LOGIN PAGE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // ===== ISI HALAMAN =====
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE INVENTORY APP
                  const Center(
                    child: Text(
                      'INVENTORY APP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // LABEL USERNAME
                  const Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _RoundedOrangeTextField(
                    controller: _usernameCtrl,
                    hintText: '',
                    orange: orange,
                    isPassword: false,
                  ),
                  const SizedBox(height: 24),

                  // LABEL PASSWORD
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _RoundedOrangeTextField(
                    controller: _passwordCtrl,
                    hintText: '',
                    orange: orange,
                    isPassword: true,
                  ),
                  const SizedBox(height: 16),

                  // TEKS "Tidak Bisa Login? Hubungi Admin"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Tidak Bisa Login?  ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: _hubungiAdmin,
                        child: const Text(
                          'Hubungi Admin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // BUTTON LOGIN ORANYE
                  Center(
                    child: Container(
                      width: 230,
                      height: 55,
                      decoration: BoxDecoration(
                        color: orange,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(0, 4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: _onLogin,
                        child: const Text(
                          'LOGIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TextField oranye rounded dengan border biru saat fokus
class _RoundedOrangeTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color orange;
  final bool isPassword;

  const _RoundedOrangeTextField({
    required this.controller,
    required this.hintText,
    required this.orange,
    required this.isPassword,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: orange,
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFF007BFF), // garis biru saat fokus
            width: 3,
          ),
        ),
      ),
    );
  }
}
