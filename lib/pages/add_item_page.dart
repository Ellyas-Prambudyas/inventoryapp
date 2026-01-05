import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';

// ===================== SUPABASE CLIENT =====================
final supabase = Supabase.instance.client;

// ===================== THEME =====================
const Color kOrange = Color(0xFFFF7A00);
const Color kBg = Color(0xFFF5F6FA);

const String kFallbackRoute = '/dashboard';

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

  final List<String> _categories = const [
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

  // ===================== SNACK MODERN =====================

  void _showSnack({
    required String title,
    required String message,
    bool success = false,
  }) {
    final color = success ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  success
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.25,
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

  // ===================== PERMISSION HELPERS =====================

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final req = await Permission.camera.request();
    if (req.isGranted) return true;

    await _showCameraPermissionGuide();
    return false;
  }

  Future<void> _showCameraPermissionGuide() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Aktifkan Izin Kamera',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Izin kamera belum aktif. Aktifkan agar bisa mengambil foto.\n\n'
          'Langkah:\n'
          'Settings > Apps > inventory > Permissions > Camera > Allow.\n'
          'Jika Vivo: cek juga iManager/Permission Manager.',
          style: TextStyle(fontSize: 12, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Buka Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureSaveGalleryPermissionIfNeeded() async {
    // Banyak device modern tidak butuh permission untuk save via MediaStore.
    // Namun pada device/OS tertentu tetap bisa butuh.
    try {
      if (Platform.isIOS) {
        // iOS: agar bisa save ke Photos
        final s = await Permission.photosAddOnly.status;
        if (!s.isGranted) {
          await Permission.photosAddOnly.request();
        }
      } else {
        // Android: fallback untuk OS lama / OEM
        final s = await Permission.storage.status;
        if (!s.isGranted) {
          await Permission.storage.request();
        }
      }
    } catch (_) {
      // Abaikan: tetap coba save, karena sebagian platform tidak membutuhkan permission.
    }
  }

  // ===================== LOGIC =====================

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImageCommon(ImageSource source) async {
    try {
      FocusScope.of(context).unfocus();

      if (source == ImageSource.camera) {
        final ok = await _ensureCameraPermission();
        if (!ok) return;
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
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
        message: source == ImageSource.camera
            ? 'Foto barang berhasil diambil.'
            : 'Gambar berhasil dipilih dari galeri.',
        success: true,
      );
    } catch (e) {
      debugPrint('PICK IMAGE ERROR: $e');
      _showSnack(
        title: 'Gagal memilih gambar',
        message: 'Error: $e',
        success: false,
      );
    }
  }

  Future<void> _showImageSourceSheet() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Text(
                  'Pilih Sumber Gambar',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Kamera'),
                  subtitle: const Text('Ambil foto langsung'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickImageCommon(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: const Text('Upload dari Galeri'),
                  subtitle: const Text('Pilih gambar dari penyimpanan'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickImageCommon(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
    _showSnack(
      title: 'Gambar dihapus',
      message: 'Foto barang dihapus dari form.',
      success: true,
    );
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

      await _ensureSaveGalleryPermissionIfNeeded();

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

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

      _showSnack(
        title: isSuccess ? 'Berhasil' : 'Gagal',
        message: isSuccess ? 'QR disimpan ke galeri.' : 'Tidak bisa menyimpan QR.',
        success: isSuccess,
      );
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
        message: 'Isi Nama Barang dan pilih Kategori terlebih dahulu.',
        success: false,
      );
      return;
    }

    final data = _buildQrData();

    await showDialog(
      context: context,
      builder: (context) {
        final media = MediaQuery.of(context);
        final w = media.size.width;
        final qrSize = (w * 0.62).clamp(180.0, 260.0);

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'QR Barang',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: qrSize,
                  height: qrSize,
                  child: RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: QrImageView(
                        data: data,
                        version: QrVersions.auto,
                        size: qrSize,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Silakan screenshot atau download QR ini untuk ditempel di barang / rak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _downloadQrImage,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download QR'),
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

  String _guessContentType(String? name) {
    final ext = (name ?? '').toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) return 'image/jpeg';
    if (ext.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }

  Future<String?> _uploadImageToSupabase(String itemId) async {
    if (_imageBytes == null) return null;

    final sanitizedName =
        (_imageName ?? 'image').replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // Jika user pilih galeri, ekstensi bisa kosong. Tetap simpan aman.
    final filePath = 'items/$itemId-$sanitizedName';

    await supabase.storage.from('item-images').uploadBinary(
          filePath,
          _imageBytes!,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: _guessContentType(_imageName),
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
        message: 'Periksa kembali field yang wajib diisi.',
        success: false,
      );
      return;
    }

    final qty = int.tryParse(_totalCtrl.text.trim());
    if (qty == null || qty <= 0) {
      _showSnack(
        title: 'Total tidak valid',
        message: 'Total harus angka lebih dari 0.',
        success: false,
      );
      return;
    }

    if (_selectedDate == null || _selectedCategory == null) {
      _showSnack(
        title: 'Data belum lengkap',
        message: 'Tanggal dan kategori wajib diisi.',
        success: false,
      );
      return;
    }

    setState(() => _saving = true);

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
        message: 'Data berhasil disimpan ke Supabase.',
        success: true,
      );

      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) Navigator.pop(context, item);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===================== UI HELPERS =====================

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  InputDecoration _dec({
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(icon, size: 18),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF3F4F6) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kOrange, width: 1.6),
      ),
    );
  }

  BoxDecoration _cardDec() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.black12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ]
        ],
      ),
    );
  }

  Widget _imagePickerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 170,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: _imageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: kOrange.withOpacity(0.10),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: kOrange.withOpacity(0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.add_a_photo_outlined,
                                color: kOrange,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Tap untuk pilih gambar',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Kamera atau Upload dari Galeri',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                if (_imageBytes != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: InkWell(
                      onTap: _removeImage,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImageCommon(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: kOrange.withOpacity(0.6)),
                    foregroundColor: kOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text(
                    'Kamera',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImageCommon(ImageSource.gallery),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text(
                    'Upload',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          if (_imageName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.image_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _imageName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          'Tambah Barang',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.black87, size: 20),
        actionsIconTheme: const IconThemeData(color: Colors.black87, size: 20),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black12),
        ),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              nav.pushReplacementNamed(kFallbackRoute);
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Lihat QR',
            onPressed: _showQrDialog,
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      decoration: _cardDec(),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: kOrange.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: kOrange.withOpacity(0.28)),
                            ),
                            child: const Icon(Icons.inventory_2_outlined,
                                color: kOrange, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Barang Masuk',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Lengkapi data, simpan ke Supabase, lalu (opsional) buat QR untuk label.',
                                  style: TextStyle(
                                      color: Colors.black54,
                                      height: 1.25,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Form
                    Container(
                      decoration: _cardDec(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionTitle(
                              'Informasi Utama',
                              subtitle: 'Field wajib: Tanggal, Kategori, Nama, Total.',
                            ),

                            // Tanggal + Kategori
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InputDecorator(
                                      decoration: _dec(
                                        label: 'Tanggal',
                                        icon: Icons.calendar_month_rounded,
                                        hint: 'Pilih tanggal',
                                      ),
                                      child: Text(
                                        _selectedDate == null
                                            ? 'Pilih tanggal'
                                            : _fmtDate(_selectedDate!),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    menuMaxHeight: 320,
                                    onTap: () => FocusScope.of(context).unfocus(),
                                    decoration: _dec(
                                      label: 'Kategori',
                                      icon: Icons.grid_view_rounded,
                                      hint: 'Pilih kategori',
                                    ),
                                    items: _categories
                                        .map((e) => DropdownMenuItem<String>(
                                              value: e,
                                              child: Text(
                                                e,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedCategory = val),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Pilih kategori'
                                        : null,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _nameCtrl,
                              decoration: _dec(
                                label: 'Nama Barang',
                                icon: Icons.inventory_2_rounded,
                                hint: 'Contoh: iPhone 14 Pro',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nama wajib diisi'
                                  : null,
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _skuCtrl,
                                    decoration: _dec(
                                      label: 'SKU',
                                      icon: Icons.qr_code_scanner_rounded,
                                      hint: 'Opsional',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _merkCtrl,
                                    decoration: _dec(
                                      label: 'Merk',
                                      icon: Icons.sell_outlined,
                                      hint: 'Opsional',
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _hargaCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: _dec(
                                      label: 'Harga',
                                      icon: Icons.payments_outlined,
                                      hint: 'Opsional, angka saja',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _totalCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: _dec(
                                      label: 'Total',
                                      icon: Icons.onetwothree_rounded,
                                      hint: 'Wajib, angka',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Total wajib diisi'
                                            : null,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _supplierCtrl,
                              decoration: _dec(
                                label: 'Supplier',
                                icon: Icons.local_shipping_outlined,
                                hint: 'Opsional',
                              ),
                            ),

                            const SizedBox(height: 16),

                            _sectionTitle('Kondisi'),
                            Wrap(
                              spacing: 10,
                              children: [
                                _ConditionPill(
                                  label: 'Baru',
                                  selected: _condition == 'Baru',
                                  onTap: () => setState(() => _condition = 'Baru'),
                                ),
                                _ConditionPill(
                                  label: 'Bekas',
                                  selected: _condition == 'Bekas',
                                  onTap: () => setState(() => _condition = 'Bekas'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            _sectionTitle(
                              'Foto Barang',
                              subtitle: 'Opsional. Bisa dari kamera atau upload galeri.',
                            ),
                            _imagePickerCard(),

                            const SizedBox(height: 18),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showQrDialog,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: kOrange),
                                      foregroundColor: kOrange,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                    label: const Text(
                                      'Lihat QR',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _onSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kOrange,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined, size: 18),
                                    label: Text(
                                      _saving ? 'Menyimpan...' : 'Simpan',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'Dengan menekan Simpan, data akan masuk ke Supabase. QR opsional untuk label barang.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.55),
                                height: 1.25,
                              ),
                            ),
                          ],
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
    );
  }
}

// ===================== CHIP KONDISI =====================

class _ConditionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kOrange : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? kOrange : Colors.black12),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: selected ? Colors.white : kOrange,
          ),
        ),
      ),
    );
  }
}
