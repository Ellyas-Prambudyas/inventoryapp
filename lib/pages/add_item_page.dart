import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../models/item_model.dart';

// ===================== SUPABASE CLIENT =====================
final supabase = Supabase.instance.client;

// ===================== TEMA WARNA (DISESUAIKAN HOME) =====================

const Color kPrimary = Color(0xFFFF7A00); // oranye utama (sama kayak home)
const Color kBackground = Color(0xFFF5F5F5); // abu-abu muda background
const Color kCardBg = Colors.white; // kartu putih
const Color kGreyBorder = Color(0xFFE3E3E3);
const Color kTextDark = Color(0xFF2E2E2E);

class AddItemPage extends StatefulWidget {
  const AddItemPage({super.key});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  String? _selectedCategory;
  String _condition = 'Baru';

  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _merkCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;

  bool _saving = false;

  final List<String> _categories = [
    'Handphone',
    'Laptop',
    'Aksesoris',
    'Elektronik Lainnya',
  ];

  final ImagePicker _picker = ImagePicker();
  final GlobalKey _qrKey = GlobalKey();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _merkCtrl.dispose();
    _hargaCtrl.dispose();
    _totalCtrl.dispose();
    _supplierCtrl.dispose();
    super.dispose();
  }

  // ===================== NOTIFIKASI =====================

  void _showSnack({
    required String title,
    required String message,
    bool success = false,
  }) {
    final color = success ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ===================== LOGIC =====================

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _imageName = p.basename(picked.path);
      });

      _showSnack(
        title: 'Gambar dipilih',
        message: 'Berhasil ambil foto barang.',
        success: true,
      );
    } catch (e) {
      _showSnack(
        title: 'Gagal ambil gambar',
        message: 'Terjadi error: $e',
        success: false,
      );
    }
  }

  String _buildQrData() {
    return '''
Inventory App - Barang Masuk
Tanggal: ${_selectedDate != null ? _selectedDate!.toIso8601String().split('T').first : '-'}
Kategori: ${_selectedCategory ?? '-'}
Nama: ${_nameCtrl.text}
SKU: ${_skuCtrl.text}
Merk: ${_merkCtrl.text}
Harga: ${_hargaCtrl.text}
Total: ${_totalCtrl.text}
Supplier: ${_supplierCtrl.text}
Kondisi: $_condition
Gambar: ${_imageName ?? '-'}
''';
  }

  Future<void> _downloadQrImage() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        _showSnack(
          title: 'Gagal',
          message: 'QR belum siap untuk di-download.',
          success: false,
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        _showSnack(
          title: 'Gagal',
          message: 'Tidak bisa mengubah QR ke gambar.',
          success: false,
        );
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: 'qr_barang_${DateTime.now().millisecondsSinceEpoch}',
      );

      final isSuccess =
          (result['isSuccess'] == true) || (result['isSuccess'] == 'true');

      if (isSuccess) {
        _showSnack(
          title: 'Berhasil',
          message: 'QR berhasil disimpan ke galeri.',
          success: true,
        );
      } else {
        _showSnack(
          title: 'Gagal',
          message: 'Tidak bisa menyimpan QR ke galeri.',
          success: false,
        );
      }
    } catch (e) {
      _showSnack(
        title: 'Gagal',
        message: 'Terjadi error saat menyimpan QR: $e',
        success: false,
      );
    }
  }

  Future<void> _showQrDialog() async {
    if (_selectedCategory == null || _nameCtrl.text.trim().isEmpty) {
      _showSnack(
        title: 'Data belum lengkap',
        message: 'Isi Nama Barang dan pilih Kategori dulu ya',
        success: false,
      );
      return;
    }

    final data = _buildQrData();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'QR Barang',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: RepaintBoundary(
                  key: _qrKey,
                  child: QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Silakan screenshot atau download QR ini untuk ditempel di barang / rak.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _downloadQrImage,
              child: const Text('Download QR'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _uploadImageToSupabase(String itemId) async {
    if (_imageBytes == null) return null;

    final sanitizedName =
        (_imageName ?? 'image').replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath = 'items/$itemId-$sanitizedName';

    await supabase.storage.from('item-images').uploadBinary(
          filePath,
          _imageBytes!,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: 'image/png',
          ),
        );

    final publicUrl =
        supabase.storage.from('item-images').getPublicUrl(filePath);
    return publicUrl;
  }

  void _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnack(
        title: 'Form belum valid',
        message: 'Periksa kembali field yang wajib diisi',
        success: false,
      );
      return;
    }

    final qty = int.tryParse(_totalCtrl.text.trim());
    if (qty == null || qty <= 0) {
      _showSnack(
        title: 'Total tidak valid',
        message: 'Total harus angka lebih dari 0',
        success: false,
      );
      return;
    }

    if (_selectedDate == null || _selectedCategory == null) {
      _showSnack(
        title: 'Data belum lengkap',
        message: 'Tanggal dan kategori wajib diisi',
        success: false,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final imageUrl = await _uploadImageToSupabase(id);

      final data = {
        'id': id,
        'name': _nameCtrl.text.trim(),
        'sku': _skuCtrl.text.trim(),
        'merk': _merkCtrl.text.trim(),
        'harga': _hargaCtrl.text.trim(),
        'total': qty,
        'supplier': _supplierCtrl.text.trim(),
        'category': _selectedCategory,
        'condition': _condition,
        'date': _selectedDate!.toIso8601String(),
        'image_name': _imageName,
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('items').insert(data);

      final item = ItemModel(
        id: id,
        name: _nameCtrl.text.trim(),
        category: '${_selectedCategory ?? ''} ($_condition)',
        quantity: qty,
      );

      _showSnack(
        title: 'Barang tersimpan',
        message: 'Data berhasil disimpan ke Supabase',
        success: true,
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.pop(context, item);
      }
    } on PostgrestException catch (e) {
      _showSnack(
        title: 'Gagal menyimpan',
        message: 'Error Supabase: ${e.message}',
        success: false,
      );
    } catch (e) {
      _showSnack(
        title: 'Gagal menyimpan',
        message: 'Terjadi kesalahan: $e',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _onBottomTap(String id) {
    _showSnack(
      title: 'Menu ditekan',
      message: 'Kamu menekan "$id"',
      success: true,
    );
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Barang Masuk',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildFormCard(context),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.home_rounded),
              color: Colors.white,
              onPressed: () => _onBottomTap('dashboard'),
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              color: Colors.white,
              onPressed: () => _onBottomTap('scan_qr'),
            ),
            IconButton(
              icon: const Icon(Icons.person_rounded),
              color: Colors.white,
              onPressed: () => _onBottomTap('profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Card(
      color: kCardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BARIS ATAS: TANGGAL + KATEGORI
              Row(
                children: [
                  Expanded(
                    child: _FieldLabelWithBox(
                      label: 'Tanggal',
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kPrimary,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDate == null
                                      ? 'Pilih tanggal'
                                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                                          '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                                          '${_selectedDate!.year}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: kTextDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FieldLabelWithBox(
                      label: 'Kategori',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: kPrimary,
                            width: 1.2,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedCategory,
                            icon: const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: kPrimary,
                            ),
                            dropdownColor: Colors.white,
                            hint: const Text(
                              'Pilih kategori',
                              style: TextStyle(
                                fontSize: 13,
                                color: kTextDark,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: _categories
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kTextDark,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategory = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // FIELD TEKS
              _ModernTextField(
                label: 'Nama Barang',
                controller: _nameCtrl,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              _ModernTextField(
                label: 'SKU',
                controller: _skuCtrl,
              ),
              const SizedBox(height: 10),
              _ModernTextField(
                label: 'Merk',
                controller: _merkCtrl,
              ),
              const SizedBox(height: 10),
              _ModernTextField(
                label: 'Harga',
                controller: _hargaCtrl,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _ModernTextField(
                label: 'Total',
                controller: _totalCtrl,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              _ModernTextField(
                label: 'Supplier',
                controller: _supplierCtrl,
              ),
              const SizedBox(height: 18),

              // KONDISI
              const Text(
                'Kondisi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ConditionChip(
                    label: 'Baru',
                    selected: _condition == 'Baru',
                    onTap: () {
                      setState(() {
                        _condition = 'Baru';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _ConditionChip(
                    label: 'Bekas',
                    selected: _condition == 'Bekas',
                    onTap: () {
                      setState(() {
                        _condition = 'Bekas';
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // GAMBAR BARANG
              const Text(
                'Gambar Barang',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kTextDark,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kGreyBorder,
                        ),
                      ),
                      child: _imageBytes == null
                          ? Icon(
                              Icons.add_a_photo_rounded,
                              color: Colors.grey.shade700,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _imageName ??
                          'Belum ada gambar. Tap ikon untuk foto / pilih gambar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // TOMBOL QR + SUBMIT
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showQrDialog,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kPrimary),
                        foregroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_rounded),
                      label: const Text(
                        'Lihat QR',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        _saving ? 'Menyimpan...' : 'Simpan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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

// ===================== WIDGET KECIL =====================

class _FieldLabelWithBox extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldLabelWithBox({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ModernTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ModernTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: kCardBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGreyBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kGreyBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary : kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kPrimary : kGreyBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : kPrimary,
          ),
        ),
      ),
    );
  }
}
