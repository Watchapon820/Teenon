import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'admin_widgets.dart';
import 'room_repository.dart';

/// ห้องพักของโรงแรมเดียว: เลือกคืนที่ต้องการดู (ค่าเริ่มต้น = วันนี้) เห็นห้องว่างของแต่ละประเภท
/// และกด − / + เพื่อลดหรือเพิ่มจำนวนห้องที่มี · ตัวเลขอัปเดตสดเองทุก 5 วินาที
///
/// ห้องว่าง = จำนวนห้องที่มี − ห้องที่ "ยืนยันแล้ว" ในคืนนั้น (การจองที่ยังรอยืนยันยังไม่ลดห้องว่าง
/// จะลดเมื่อแอดมินกดยืนยันในแท็บ "การจอง")
class AdminHotelRoomsScreen extends StatefulWidget {
  const AdminHotelRoomsScreen({
    super.key,
    required this.repository,
    required this.hotelId,
    required this.hotelName,
    required this.onAddRoom,
    required this.onEditRoom,
    required this.onDeleteRoom,
  });

  final RoomRepository repository;
  final int hotelId;
  final String hotelName;

  /// เปิดฟอร์มเพิ่ม/แก้ไข/ลบห้อง (ทำที่หน้าแอดมินหลัก) คืนเมื่อทำเสร็จ — หน้านี้จะโหลดรายการใหม่ให้
  final Future<void> Function(int hotelId) onAddRoom;
  final Future<void> Function(RoomItem room) onEditRoom;
  final Future<void> Function(RoomItem room) onDeleteRoom;

  @override
  State<AdminHotelRoomsScreen> createState() => _AdminHotelRoomsScreenState();
}

class _AdminHotelRoomsScreenState extends State<AdminHotelRoomsScreen> {
  List<RoomItem>? _rooms;
  Object? _error;
  final Set<int> _busy = {};
  bool _changed = false; // มีการเปลี่ยนจำนวนห้อง → หน้าก่อนหน้าควรรีเฟรช
  late DateTime _date = _today();
  Timer? _timer;
  bool _loading = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _show(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  bool get _isToday => _date == _today();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // โหลดเงียบ ๆ (ไม่กระพริบ): ถ้ารอบนี้พลาดแต่มีข้อมูลเดิมอยู่ ยังแสดงข้อมูลเดิมต่อ
  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final asked = _date;
    try {
      final all = await widget.repository.listRooms(date: _ymd(asked));
      if (!mounted || asked != _date) return; // ผู้ใช้เปลี่ยนวันที่ระหว่างโหลด → ทิ้งผลเก่า
      setState(() {
        _rooms = all.where((r) => r.hotelId == widget.hotelId).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted && _rooms == null) setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _setDate(DateTime d) {
    setState(() {
      _date = d;
      _rooms = _rooms; // คงรายการเดิมไว้ระหว่างรอข้อมูลของวันใหม่
    });
    _load();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: DateTime(today.year + 3, today.month, today.day),
      helpText: 'เลือกคืนที่ต้องการดูห้องว่าง',
    );
    if (d != null) _setDate(d);
  }

  Future<void> _adjust(RoomItem room, int delta) async {
    if (_busy.contains(room.id)) return;
    setState(() => _busy.add(room.id));
    try {
      await widget.repository.adjustQuantity(room, delta);
      _changed = true;
      _loading = false; // ให้โหลดทับได้ทันที
      await _load(); // ดึงค่าของคืนที่กำลังดูใหม่ (ห้องว่างคำนวณที่ server)
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _busy.remove(room.id));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    _changed = true;
    _loading = false;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _rooms;
    final total = rooms?.fold<int>(0, (s, r) => s + r.quantity) ?? 0;
    final free = rooms?.fold<int>(0, (s, r) => s + r.available) ?? 0;
    final confirmed = rooms?.fold<int>(0, (s, r) => s + r.bookedTonight) ?? 0;
    final waiting = rooms?.fold<int>(0, (s, r) => s + r.pending) ?? 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.hotelName, overflow: TextOverflow.ellipsis)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _run(() => widget.onAddRoom(widget.hotelId)),
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มประเภทห้อง'),
        ),
        body: _body(rooms, total, free, confirmed, waiting),
      ),
    );
  }

  Widget _dateBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(tooltip: 'วันก่อนหน้า', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _setDate(_date.subtract(const Duration(days: 1)))),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text('คืนวันที่ ${_show(_date)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(_isToday ? 'วันนี้ · แตะเพื่อเลือกวันอื่น' : 'แตะเพื่อเลือกวันอื่น', style: const TextStyle(color: AppColors.textSoft, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(tooltip: 'วันถัดไป', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _setDate(_date.add(const Duration(days: 1)))),
            if (!_isToday) TextButton(onPressed: () => _setDate(_today()), child: const Text('วันนี้')),
          ],
        ),
      ),
    );
  }

  Widget _body(List<RoomItem>? rooms, int total, int free, int confirmed, int waiting) {
    if (_error != null && rooms == null) return Center(child: Text(errorText(_error!)));
    if (rooms == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () async {
        _loading = false;
        await _load();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _dateBar(),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _stat('ห้องว่าง', '$free', free == 0 && total > 0 ? AppColors.danger : AppColors.success)),
                      Expanded(child: _stat('ห้องทั้งหมด', '$total', AppColors.navy)),
                      Expanded(child: _stat('ยืนยันแล้ว', '$confirmed', AppColors.adminBlue)),
                    ],
                  ),
                  if (waiting > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 15, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'รอยืนยัน $waiting ห้อง — ยังไม่ลดห้องว่าง จะลดเมื่อกดยืนยันในแท็บ "การจอง"',
                            style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 7, color: AppColors.success),
                      SizedBox(width: 5),
                      Text('อัปเดตสดทุก 5 วินาที', style: TextStyle(color: AppColors.textSoft, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('โรงแรมนี้ยังไม่มีห้องพัก กด "เพิ่มประเภทห้อง" เพื่อเริ่มต้น')),
            ),
          for (final r in rooms) ...[
            _roomCard(r),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
        ],
      );

  Widget _roomCard(RoomItem r) {
    final busy = _busy.contains(r.id);
    final full = r.available == 0;
    final details = [
      if (r.bedType != null) r.bedType!,
      if (r.sizeSqm != null) '${r.sizeSqm} ตร.ม.',
      if (r.maxGuests != null) 'พักได้ ${r.maxGuests} คน',
    ].join(' • ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            ImageThumb(url: r.imageUrl, icon: Icons.bed_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('${r.price}฿ / คืน${details.isEmpty ? '' : ' • $details'}', style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    full ? 'ห้องเต็ม (ยืนยันแล้ว ${r.bookedTonight} จาก ${r.quantity})' : 'ว่าง ${r.available} จาก ${r.quantity} ห้อง',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: full ? AppColors.danger : AppColors.success),
                  ),
                  Text(
                    'ยืนยันแล้ว ${r.bookedTonight} · รอยืนยัน ${r.pending} ห้อง',
                    style: TextStyle(color: r.pending > 0 ? AppColors.warning : AppColors.textSoft, fontSize: 12, fontWeight: r.pending > 0 ? FontWeight.w700 : FontWeight.w400),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'ลดจำนวนห้อง',
                      onPressed: busy || r.quantity <= 0 ? null : () => _adjust(r, -1),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 36,
                      child: Center(
                        child: busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('${r.quantity}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'เพิ่มจำนวนห้อง',
                      onPressed: busy ? null : () => _adjust(r, 1),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'แก้ไขรายละเอียดห้อง',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _run(() => widget.onEditRoom(r)),
                    ),
                    IconButton(
                      tooltip: 'ลบห้อง',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                      onPressed: () => _run(() => widget.onDeleteRoom(r)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
