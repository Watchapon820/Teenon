import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import 'admin_widgets.dart';

/// เพิ่ม/แก้ไขโรงแรม: ข้อมูลทั่วไป สิ่งอำนวยความสะดวก นโยบายยกเลิก แท็ก รูปหลัก และแกลเลอรีรูป
/// ปิดหน้าด้วยค่า true เมื่อมีการเปลี่ยนแปลง (ให้หน้าก่อนหน้าโหลดรายการใหม่)
class AdminHotelEditScreen extends StatefulWidget {
  const AdminHotelEditScreen({super.key, this.hotel});

  /// ข้อมูลโรงแรมจาก GET /api/hotels (null = เพิ่มโรงแรมใหม่)
  final Map<String, dynamic>? hotel;

  @override
  State<AdminHotelEditScreen> createState() => _AdminHotelEditScreenState();
}

class _NewImage {
  _NewImage(this.file, this.bytes);
  final XFile file;
  final Uint8List bytes;
}

class _AdminHotelEditScreenState extends State<AdminHotelEditScreen> {
  late final Map<String, dynamic>? h = widget.hotel;
  late final _name = TextEditingController(text: '${h?['name'] ?? ''}');
  late final _location = TextEditingController(text: '${h?['location'] ?? ''}');
  late final _desc = TextEditingController(text: '${h?['description'] ?? ''}');
  late final _policy = TextEditingController(text: '${h?['cancellation_policy'] ?? ''}');
  late final _freeDays = TextEditingController(text: '${h?['free_cancel_days'] ?? 3}');
  late final _tags = TextEditingController(text: ((h?['tags'] as List?) ?? []).join(', '));
  final _mainImage = PickedImage();

  late bool _pool = _flag(h?['has_pool'], true);
  late bool _breakfast = _flag(h?['has_breakfast'], true);
  late bool _wifi = _flag(h?['has_wifi'], true);

  List<Map<String, dynamic>> _existing = []; // รูปแกลเลอรีเดิม {id, image_url}
  final Set<int> _removed = {};
  final List<_NewImage> _added = [];
  bool _loadingGallery = false;
  bool _saving = false;

  bool _flag(dynamic v, bool fallback) => v == null ? fallback : (v == true || v == 1 || '$v' == '1' || '$v' == 'true');

  int? get _id => h == null ? null : int.tryParse('${h!['hotel_id']}');

  @override
  void initState() {
    super.initState();
    if (_id != null) _loadGallery();
  }

  @override
  void dispose() {
    for (final c in [_name, _location, _desc, _policy, _freeDays, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _loadGallery() async {
    setState(() => _loadingGallery = true);
    try {
      final list = await ApiService.adminGetHotelImages(_id!);
      if (mounted) setState(() => _existing = list);
    } catch (e) {
      if (mounted) _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _loadingGallery = false);
    }
  }

  Future<void> _addImages() async {
    final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 85);
    if (files.isEmpty) return;
    final items = <_NewImage>[];
    for (final f in files) {
      items.add(_NewImage(f, await f.readAsBytes()));
    }
    if (mounted) setState(() => _added.addAll(items));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return _toast('กรอกชื่อโรงแรม');
    final days = int.tryParse(_freeDays.text.trim());
    if (days == null || days < 0) return _toast('จำนวนวันยกเลิกฟรีต้องเป็นตัวเลข 0 ขึ้นไป');
    setState(() => _saving = true);
    try {
      final image = await _mainImage.upload();
      int id;
      if (_id == null) {
        final r = await ApiService.createHotel({
          'name': name,
          'location': _location.text.trim(),
          'description': _desc.text.trim(),
          'has_pool': _pool ? 1 : 0,
          'has_breakfast': _breakfast ? 1 : 0,
          'has_wifi': _wifi ? 1 : 0,
          if (image != null) 'image_url': image,
        });
        id = (r['hotelId'] as num).toInt();
      } else {
        id = _id!;
        await ApiService.adminUpdateHotel(id, {
          'name': name,
          'location': _location.text.trim(),
          'description': _desc.text.trim(),
          'hasPool': _pool,
          'hasBreakfast': _breakfast,
          'hasWifi': _wifi,
          if (image != null) 'imageUrl': image,
        });
      }
      await ApiService.adminUpdateHotel(id, {'cancellationPolicy': _policy.text.trim(), 'freeCancelDays': days});
      await ApiService.adminSetTags(id, _tags.text.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList());
      for (final imgId in _removed) {
        await ApiService.adminDeleteHotelImage(imgId);
      }
      for (final n in _added) {
        await ApiService.adminAddHotelImage(id, n.file);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(errorText(e));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบโรงแรม'),
        content: Text('ลบ "${_name.text}" พร้อมห้องพัก แท็ก และรูปทั้งหมด?\n(ลบไม่ได้ถ้ามีรายการจองอ้างอิงอยู่)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await ApiService.adminDeleteHotel(_id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(errorText(e));
    }
  }

  Widget _galleryTile({required Widget image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 92, height: 92, child: image)),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _id != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'แก้ไขโรงแรม' : 'เพิ่มโรงแรม'),
        actions: [
          if (editing) IconButton(tooltip: 'ลบโรงแรม', icon: const Icon(Icons.delete_outline_rounded), onPressed: _saving ? null : _delete),
          TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: [
            const Text('รูปหลัก', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ImagePickerField(picked: _mainImage, currentUrl: ApiService.imageUrl(h?['image_url']), height: 170),
            const SizedBox(height: 8),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'ชื่อโรงแรม')),
            const SizedBox(height: 12),
            TextField(controller: _location, decoration: const InputDecoration(labelText: 'ที่ตั้ง / จังหวัด')),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'รายละเอียด', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(labelText: 'แท็ก (คั่นด้วยเครื่องหมายจุลภาค)', hintText: 'เช่น ติดทะเล, รีสอร์ท, ใกล้ธรรมชาติ'),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('แท็กใช้ในหมวด ทะเล / ในเมือง / ธรรมชาติ ของหน้าแรก และการค้นหา', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  SwitchListTile(title: const Text('สระว่ายน้ำ'), value: _pool, onChanged: (v) => setState(() => _pool = v)),
                  SwitchListTile(title: const Text('รวมอาหารเช้า'), value: _breakfast, onChanged: (v) => setState(() => _breakfast = v)),
                  SwitchListTile(title: const Text('Wi‑Fi ฟรี'), value: _wifi, onChanged: (v) => setState(() => _wifi = v)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('นโยบายการยกเลิก', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _freeDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ยกเลิกฟรีก่อนเช็คอิน (วัน)', helperText: '0 = ยกเลิกได้ถึงวันเช็คอิน'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _policy,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ข้อความนโยบายเพิ่มเติม (ไม่บังคับ)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Text('แกลเลอรีรูปเพิ่มเติม', style: TextStyle(fontWeight: FontWeight.w800))),
                TextButton.icon(onPressed: _saving ? null : _addImages, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('เพิ่มรูป')),
              ],
            ),
            if (_loadingGallery) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _existing.where((e) => !_removed.contains((e['id'] as num).toInt())))
                  _galleryTile(
                    image: Image.network(ApiService.imageUrl(e['image_url']) ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                    onRemove: () => setState(() => _removed.add((e['id'] as num).toInt())),
                  ),
                for (final n in _added)
                  _galleryTile(image: Image.memory(n.bytes, fit: BoxFit.cover), onRemove: () => setState(() => _added.remove(n))),
              ],
            ),
            if (_existing.isEmpty && _added.isEmpty && !_loadingGallery)
              const Text('ยังไม่มีรูปเพิ่มเติม — ลูกค้าจะเห็นรูปหลักอย่างเดียว', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
