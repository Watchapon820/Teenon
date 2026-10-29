import 'package:flutter/material.dart';

import '../api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'hotel_api_detail_screen.dart';
import 'hotel_list_screen.dart';

/// โรงแรมที่ผู้ใช้กดดาวไว้จากหน้า Hotels (เก็บในฐานข้อมูลของผู้ใช้แต่ละคน)
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  // รายการที่แสดงอยู่ (แก้บนหน้าจอทันทีเมื่อกดดาวออก ไม่ต้องรอเซิร์ฟเวอร์)
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.getSavedHotels();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _unsave(Map<String, dynamic> hotel) async {
    final id = int.tryParse('${hotel['hotel_id']}') ?? 0;
    final index = _items.indexOf(hotel);
    setState(() => _items.remove(hotel)); // หายทันที
    try {
      await ApiService.setHotelSaved(id, false);
    } catch (e) {
      if (!mounted) return;
      // ถ้าไม่สำเร็จให้ใส่กลับที่เดิม
      setState(() => _items.insert(index.clamp(0, _items.length), hotel));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: 2,
      title: 'โรงแรมที่คุณชอบ',
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const AppSectionTitle(title: 'ที่พักที่บันทึกไว้', subtitle: 'โรงแรมที่คุณบันทึกไว้ดูภายหลัง'),
          const SizedBox(height: 14),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text('ยังไม่มีโรงแรมที่บันทึกไว้\nกดดาวที่มุมขวาบนของโรงแรมในหน้า Hotels', textAlign: TextAlign.center),
              ),
            ),
          for (final h in List.of(_items)) ...[
            _card(h),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> h) {
    final id = int.tryParse('${h['hotel_id']}') ?? 0;
    return HotelApiCard(
      key: ValueKey(id),
      name: h['name']?.toString() ?? '-',
      location: h['location']?.toString() ?? '',
      subtitle: (h['description'] ?? '').toString().trim(),
      rating: _num(h['rating']),
      price: _num(h['starting_price']),
      gradient: hotelGradients[id % hotelGradients.length],
      imageUrl: ApiService.imageUrl(h['image_url']),
      roomsAvailable: roomsAvailableOf(h),
      dealPercent: dealPercentOf(h),
      dealPrice: dealPriceOf(h),
      saved: true,
      onToggleSaved: () => _unsave(h),
      onTap: () async {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => HotelApiDetailScreen(
              hotelId: id,
              hotelName: h['name']?.toString() ?? '',
              gradient: hotelGradients[id % hotelGradients.length],
            ),
          ),
        );
        if (mounted) _load(); // กลับมาแล้วอัปเดตรายการ (อาจกดหัวใจเปลี่ยนในหน้ารายละเอียด)
      },
    );
  }
}
