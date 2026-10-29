import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';

/// รูปที่แอดมินเลือกในฟอร์ม (ยังไม่อัปโหลดจนกว่าจะกดบันทึก)
class PickedImage {
  XFile? file;

  /// อัปโหลดรูปที่เลือก คืน path บน server หรือ null ถ้าไม่ได้เลือกรูปใหม่
  Future<String?> upload() async => file == null ? null : ApiService.adminUploadImage(file!);
}

/// ช่องเลือกรูป 1 รูป พร้อมพรีวิว (รูปเดิมจาก server หรือรูปที่เพิ่งเลือก)
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({super.key, required this.picked, this.currentUrl, this.height = 140});

  final PickedImage picked;
  final String? currentUrl;
  final double height;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  Uint8List? _bytes;

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() {
      widget.picked.file = f;
      _bytes = b;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_bytes != null) {
      // ไม่กำหนด width/height เป็น infinity: ใน AlertDialog (IntrinsicWidth) จะ layout พังจนหน้าต่างว่างเปล่า
      child = Image.memory(_bytes!, fit: BoxFit.cover);
    } else if (widget.currentUrl != null) {
      child = Image.network(
        widget.currentUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
      );
    } else {
      child = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.add_photo_alternate_outlined, size: 40), SizedBox(height: 4), Text('แตะเพื่อเลือกรูป')],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _pick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: widget.height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
          child: child,
        ),
      ),
    );
  }
}

/// รูปย่อสี่เหลี่ยมมุมมน (ใช้ในรายการ)
class ImageThumb extends StatelessWidget {
  const ImageThumb({super.key, required this.url, required this.icon});

  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(color: Colors.black12, child: Icon(icon));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52,
        height: 52,
        child: url == null ? fallback() : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback()),
      ),
    );
  }
}

/// แปลงข้อความ error จาก Exception ให้อ่านง่าย
String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');
