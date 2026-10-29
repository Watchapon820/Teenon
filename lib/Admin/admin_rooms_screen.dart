import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../auth/session.dart';
import '../screens/login_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'admin_bookings_tab.dart';
import 'admin_chat_tab.dart';
import 'admin_deals_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_hotel_rooms_screen.dart';
import 'admin_hotel_edit_screen.dart';
import 'admin_widgets.dart';
import 'room_repository.dart';

/// หน้าแอดมิน: ภาพรวม · การจอง · โรงแรม · ห้องพัก · ดีล · แชท
class AdminRoomsScreen extends StatefulWidget {
  const AdminRoomsScreen({super.key, required this.repository});

  final RoomRepository repository;

  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this)..addListener(() => setState(() {}));
  final ValueNotifier<String> _bookingFilter = ValueNotifier('all');
  int _statsKey = 0;
  int _chatUnread = 0; // ข้อความลูกค้าที่ยังไม่ได้อ่าน (ป้ายที่แท็บแชท)
  Timer? _chatTimer;
  Timer? _hotelsTimer;
  List<Map<String, dynamic>>? _hotelsLive; // ข้อมูลโรงแรมที่อัปเดตเงียบ ๆ ทุก 8 วินาที (ไม่ทำให้หน้ากระพริบ)

  late Future<List<Map<String, dynamic>>> _hotels;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadChatUnread();
    _chatTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadChatUnread());
    // แท็บ "ห้องพัก": ห้องว่างเปลี่ยนเมื่อลูกค้าจอง/แอดมินกดยืนยัน → ดึงใหม่เองขณะเปิดแท็บนี้
    _hotelsTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_tabs.index == 3) _pollHotels();
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _hotelsTimer?.cancel();
    _tabs.dispose();
    _bookingFilter.dispose();
    super.dispose();
  }

  Future<void> _loadChatUnread() async {
    final n = await ApiService.adminChatUnread();
    if (mounted && n != _chatUnread) setState(() => _chatUnread = n);
  }

  void _reload() {
    _hotels = ApiService.getHotels();
    _hotelsLive = null;
  }

  Future<void> _pollHotels() async {
    try {
      final list = await ApiService.getHotels();
      if (mounted) setState(() => _hotelsLive = list);
    } catch (_) {} // เงียบ ๆ: รอบหน้าลองใหม่เอง
  }

  void _refresh() => setState(() {
        _reload();
        _statsKey++;
      });

  void _toast(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is String ? e : errorText(e))));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _refresh();
    } catch (e) {
      _toast(e);
    }
  }

  // ---------- ห้องพัก ----------
  Future<void> _roomDialog({RoomItem? room, int? hotelId}) async {
    List<Map<String, dynamic>> hotels = [];
    try {
      hotels = await _hotels;
    } catch (_) {}
    if (!mounted) return;
    final nameC = TextEditingController(text: room?.name ?? '');
    final priceC = TextEditingController(text: room == null ? '' : room.price.toString());
    final qtyC = TextEditingController(text: '${room?.quantity ?? 1}');
    final guestsC = TextEditingController(text: room?.maxGuests?.toString() ?? '');
    final bedC = TextEditingController(text: room?.bedType ?? '');
    final sizeC = TextEditingController(text: room?.sizeSqm?.toString() ?? '');
    int? selectedHotel = room?.hotelId ?? hotelId ?? (hotels.isNotEmpty ? int.tryParse('${hotels.first['hotel_id']}') : null);
    final picked = PickedImage();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(room == null ? 'เพิ่มห้องพัก' : 'แก้ไขห้องพัก'),
          // กำหนดความกว้างตายตัว: รูปพรีวิวเต็มความกว้างใน AlertDialog (IntrinsicWidth) ต้องมีขนาดแน่นอน ไม่งั้น layout พัง
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ImagePickerField(picked: picked, currentUrl: room?.imageUrl),
                if (room == null && hotelId == null)
                  DropdownButtonFormField<int>(
                    value: selectedHotel,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'โรงแรม'),
                    items: [
                      for (final h in hotels)
                        DropdownMenuItem(value: int.tryParse('${h['hotel_id']}'), child: Text('${h['name']}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setD(() => selectedHotel = v),
                  ),
                const SizedBox(height: 8),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'ชื่อ/ประเภทห้อง')),
                const SizedBox(height: 8),
                TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ราคาต่อคืน (฿)')),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'จำนวนห้องที่มี', helperText: 'ใช้ตรวจห้องว่าง — เต็มแล้วลูกค้าจองไม่ได้'),
                ),
                const SizedBox(height: 8),
                TextField(controller: guestsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'พักได้สูงสุด (คน/ห้อง)')),
                const SizedBox(height: 8),
                TextField(controller: bedC, decoration: const InputDecoration(labelText: 'ประเภทเตียง', hintText: 'เช่น King, Twin')),
                const SizedBox(height: 8),
                TextField(controller: sizeC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ขนาดห้อง (ตร.ม.)')),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
          ],
        ),
      ),
    );
    final name = nameC.text.trim();
    final price = num.tryParse(priceC.text.trim());
    final qty = int.tryParse(qtyC.text.trim());
    final guests = int.tryParse(guestsC.text.trim());
    final size = int.tryParse(sizeC.text.trim());
    final bed = bedC.text.trim();
    for (final c in [nameC, priceC, qtyC, guestsC, bedC, sizeC]) {
      c.dispose();
    }
    if (ok != true) return;
    if (name.isEmpty || price == null || price < 0) return _toast('กรอกชื่อห้องและราคาให้ถูกต้อง');
    if (qty == null || qty < 1) return _toast('จำนวนห้องที่มีต้องเป็นตัวเลขตั้งแต่ 1');
    if (room == null && selectedHotel == null) return _toast('เลือกโรงแรม');
    await _run(() async {
      final image = await picked.upload();
      if (room == null) {
        await widget.repository.addRoom(hotelId: selectedHotel!, name: name, price: price, imageUrl: image, quantity: qty, maxGuests: guests, bedType: bed, sizeSqm: size);
      } else {
        await widget.repository.updateRoom(room.id, name: name, price: price, imageUrl: image, quantity: qty, maxGuests: guests, bedType: bed, sizeSqm: size);
      }
    });
  }

  Future<void> _confirmDeleteRoom(RoomItem room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบห้องพัก'),
        content: Text('ลบ "${room.name}" ของ ${room.hotelName} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok == true) await _run(() => widget.repository.deleteRoom(room.id));
  }

  // ---------- โรงแรม ----------
  Future<void> _openHotel([Map<String, dynamic>? hotel]) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AdminHotelEditScreen(hotel: hotel)));
    if (changed == true) _refresh();
  }

  void _logout() {
    Session.clear();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabs.index;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        titleSpacing: 20,
        title: Row(
          children: [
            const AppLogo(size: 44, admin: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Teenon Admin', style: TextStyle(color: AppColors.navy, fontSize: 21, fontWeight: FontWeight.w800, height: 1.1)),
                  Text(Session.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSoft, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(style: appBarIconStyleWith(AppColors.adminBlue, AppColors.adminBorder), tooltip: 'รีเฟรช', icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
          const SizedBox(width: 6),
          IconButton(style: appBarIconStyleWith(AppColors.danger, AppColors.adminBorder), tooltip: 'ออกจากระบบ', icon: const Icon(Icons.logout_rounded), onPressed: _logout),
          const SizedBox(width: 16),
        ],
      ),
      bottomNavigationBar: PillNavBar(
        color: AppColors.adminBlue,
        currentIndex: tab,
        onTap: (i) => _tabs.animateTo(i),
        items: [
          const NavItem(Icons.dashboard_rounded, 'ภาพรวม'),
          const NavItem(Icons.receipt_long_rounded, 'การจอง'),
          const NavItem(Icons.apartment_rounded, 'โรงแรม'),
          const NavItem(Icons.bed_rounded, 'ห้องพัก'),
          const NavItem(Icons.local_offer_rounded, 'ดีล'),
          NavItem(Icons.chat_bubble_rounded, 'แชท', badge: _chatUnread),
        ],
      ),
      floatingActionButton: tab == 2
          ? FloatingActionButton.extended(onPressed: () => _openHotel(), icon: const Icon(Icons.add_business_rounded), label: const Text('เพิ่มโรงแรม'))
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          AdminDashboardTab(
            refreshKey: _statsKey,
            onOpenBookings: (f) {
              _bookingFilter.value = f;
              _tabs.animateTo(1);
            },
          ),
          AdminBookingsTab(filter: _bookingFilter, onChanged: () => setState(() => _statsKey++)),
          _hotelsTab(),
          _roomsTab(),
          const AdminDealsTab(),
          AdminChatTab(onChanged: _loadChatUnread),
        ],
      ),
    );
  }

  Widget _hotelsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _hotels,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(errorText(snap.error!)));
        final list = snap.data!;
        if (list.isEmpty) return const Center(child: Text('ยังไม่มีโรงแรม กด "เพิ่มโรงแรม" เพื่อเริ่มต้น'));
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final h = list[i];
              final tags = ((h['tags'] as List?) ?? []).join(', ');
              return Card(
                child: ListTile(
                  onTap: () => _openHotel(h),
                  leading: ImageThumb(url: ApiService.imageUrl(h['image_url']), icon: Icons.apartment_rounded),
                  title: Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${h['location'] ?? ''}${tags.isEmpty ? '' : '\n$tags'}'),
                  isThreeLine: tags.isNotEmpty,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // เปิดหน้าห้องพักของโรงแรมนั้น (เพิ่ม/ลดจำนวนห้อง, เพิ่ม/แก้ไข/ลบประเภทห้อง)
  Future<void> _openHotelRooms(Map<String, dynamic> h) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminHotelRoomsScreen(
          repository: widget.repository,
          hotelId: int.tryParse('${h['hotel_id']}') ?? 0,
          hotelName: '${h['name']}',
          onAddRoom: (hotelId) => _roomDialog(hotelId: hotelId),
          onEditRoom: (room) => _roomDialog(room: room),
          onDeleteRoom: _confirmDeleteRoom,
        ),
      ),
    );
    if (changed == true) _refresh();
  }

  // ห้องพักแยกตามโรงแรม: กดโรงแรมเพื่อเข้าไปดู/ปรับจำนวนห้อง
  Widget _roomsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _hotels,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text(errorText(snap.error!)));
        final hotels = _hotelsLive ?? snap.data!;
        if (hotels.isEmpty) return const Center(child: Text('ยังไม่มีโรงแรม เพิ่มโรงแรมในแท็บ "โรงแรม" ก่อน'));
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: hotels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final h = hotels[i];
              final total = int.tryParse('${h['rooms_total']}') ?? 0;
              final free = int.tryParse('${h['rooms_available']}') ?? 0;
              final color = total == 0 ? AppColors.textSoft : (free == 0 ? AppColors.danger : AppColors.success);
              return Card(
                child: ListTile(
                  onTap: () => _openHotelRooms(h),
                  leading: ImageThumb(url: ApiService.imageUrl(h['image_url']), icon: Icons.apartment_rounded),
                  title: Text('${h['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    total == 0 ? 'ยังไม่มีห้องพัก' : 'ว่างคืนนี้ $free จาก $total ห้อง',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
