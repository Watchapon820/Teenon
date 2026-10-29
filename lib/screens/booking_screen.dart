import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../auth/session.dart';
import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, this.hotel, this.hotelId, this.hotelName});

  /// โรงแรมจากหน้ารายละเอียด (ข้อมูลเดิมของแอป) ถ้ามีจะไปต่อที่หน้าชำระเงิน
  final Hotel? hotel;

  /// hotel_id ในฐานข้อมูล ถ้าไม่ส่งมาจะจับคู่จากชื่อโรงแรมให้อัตโนมัติ
  final int? hotelId;

  /// ชื่อโรงแรม (ใช้เมื่อไม่มี [hotel] เช่น เปิดจากหน้ารายการที่ดึงจาก API)
  final String? hotelName;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // userId มาจาก token ที่ล็อกอิน (server อ่านจาก Authorization header)

  static const List<String> _months = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _requestCtrl = TextEditingController();

  int? _dbHotelId;
  Map<String, dynamic> _hotelInfo = {};
  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _selectedRoom;
  late DateTime _checkIn;
  late DateTime _checkOut;
  int _numRooms = 1;
  int _numGuests = 2;

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  // เก็บรหัสการจองหลังบันทึกแล้ว กันการกดซ้ำแล้วเกิดการจองซ้ำในฐานข้อมูล
  String? _bookingCode;

  String get _displayName => widget.hotel?.name ?? widget.hotelName ?? '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _checkIn = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _checkOut = _checkIn.add(const Duration(days: 2));
    // เติมข้อมูลผู้จองจากบัญชีที่ล็อกอิน (แก้ไขได้)
    _nameCtrl.text = Session.name;
    _emailCtrl.text = Session.email;
    _phoneCtrl.text = Session.phone;
    _load();
    // ห้องว่างเปลี่ยนเมื่อแอดมินกดยืนยันการจองของคนอื่น → ดึงใหม่เองทุก 5 วินาที
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _loadAvail());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _requestCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      int? id = widget.hotelId;
      if (id == null) {
        // จับคู่โรงแรมในแอปกับโรงแรมในฐานข้อมูลด้วยชื่อ ถ้าไม่ตรงใช้โรงแรมแรกในฐานข้อมูล
        final list = await ApiService.getHotels();
        if (list.isEmpty) {
          throw Exception('ยังไม่มีข้อมูลโรงแรมในฐานข้อมูล');
        }
        final name = _displayName.trim();
        final match = list.where((h) => h['name']?.toString().trim() == name).toList();
        final picked = match.isNotEmpty ? match.first : list.first;
        id = int.parse(picked['hotel_id'].toString());
      }

      final data = await ApiService.getHotelById(id);
      final rooms = (data['rooms'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

      // ข้อมูลโรงแรมอาจซ้อนอยู่ใน 'hotel' หรืออยู่ระดับบนสุดของ response
      final info = data['hotel'] is Map ? Map<String, dynamic>.from(data['hotel']) : Map<String, dynamic>.from(data);

      setState(() {
        _dbHotelId = id;
        _hotelInfo = info;
        _rooms = rooms;
        _selectedRoom = rooms.isNotEmpty ? rooms.first : null;
        _clampGuests();
        _loading = false;
      });
      _loadAvail();
    } catch (e) {
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  String _fmtDb(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtShow(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  int get _nights => _checkOut.difference(_checkIn).inDays;

  // ดีลของโรงแรมที่ใช้ได้ตอนนี้ (server แนบมาให้ และหักส่วนลดตอนจองจริงเสมอ)
  Map<String, dynamic>? get _deal => _hotelInfo['deal'] is Map ? Map<String, dynamic>.from(_hotelInfo['deal']) : null;

  // ราคาต่อคืนของห้อง: ถ้ามีดีลใช้ราคาหลังลด (deal_price จาก server)
  double _unitPrice(Map<String, dynamic> r) {
    final d = _toDouble(r['deal_price']);
    return _deal != null && d > 0 ? d : _toDouble(r['price_per_night']);
  }

  double? _serverTotal; // ยอดที่ server คำนวณตอนสร้างการจอง (ใช้แสดงในหน้าชำระเงิน)

  // ยอดประมาณการเพื่อแสดงผล — ยอดจริงคิดที่ server และจะตรงกับตัวเลขนี้
  double get _total {
    if (_selectedRoom == null || _nights < 1) return 0;
    return _unitPrice(_selectedRoom!) * _nights * _numRooms;
  }

  // ยอดก่อนหักส่วนลด (ไว้ขีดฆ่าเมื่อมีดีล)
  double get _originalTotal {
    if (_selectedRoom == null || _nights < 1) return 0;
    return _toDouble(_selectedRoom!['price_per_night']) * _nights * _numRooms;
  }

  // จำนวนผู้เข้าพักสูงสุดต่อห้องของห้องที่เลือก (null = ไม่จำกัด)
  int? get _maxGuestsPerRoom => int.tryParse('${_selectedRoom?['max_guests']}');

  int get _guestLimit => (_maxGuestsPerRoom ?? 10) * _numRooms > 20 ? 20 : (_maxGuestsPerRoom ?? 10) * _numRooms;

  void _clampGuests() {
    if (_numGuests > _guestLimit) _numGuests = _guestLimit;
  }

  String _roomDetail(Map<String, dynamic> r) {
    final parts = <String>[
      if ('${r['bed_type'] ?? ''}'.isNotEmpty) '${r['bed_type']}',
      if (int.tryParse('${r['size_sqm']}') != null) '${r['size_sqm']} ตร.ม.',
      if (int.tryParse('${r['max_guests']}') != null) 'พักได้ ${r['max_guests']} คน/ห้อง',
    ];
    return parts.join(' • ');
  }

  // นโยบายยกเลิกของโรงแรม + วันสุดท้ายที่ยกเลิกฟรี (คำนวณจากวันเช็คอินที่เลือก)
  Widget _policyCard() {
    final days = int.tryParse('${_hotelInfo['free_cancel_days']}') ?? 3;
    final custom = '${_hotelInfo['cancellation_policy'] ?? ''}'.trim();
    final lastFree = _checkIn.subtract(Duration(days: days));
    final now = DateTime.now();
    final stillFree = !DateTime(now.year, now.month, now.day).isAfter(lastFree);
    final line = days <= 0
        ? 'ยกเลิกได้ถึงวันเช็คอิน'
        : (stillFree ? 'ยกเลิกฟรีได้ถึงวันที่ ${_fmtShow(lastFree)}' : 'เลยช่วงยกเลิกฟรีแล้ว (ก่อนเช็คอิน $days วัน)');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('นโยบายการยกเลิก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(stillFree ? Icons.event_available_rounded : Icons.event_busy_rounded, color: stillFree ? AppColors.success : AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text))),
              ],
            ),
            if (custom.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(custom, style: const TextStyle(color: AppColors.textSoft, fontSize: 13, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  bool _flag(dynamic v) => v == true || v == 1 || v?.toString() == '1' || v?.toString() == 'true';

  // เวลาจาก MySQL เป็น "14:00:00" ตัดวินาทีออก
  String _time(List<String> keys, String fallback) {
    for (final k in keys) {
      final s = _hotelInfo[k]?.toString() ?? '';
      if (s.isNotEmpty) return s.length >= 5 ? s.substring(0, 5) : s;
    }
    return fallback;
  }

  // การ์ดข้อมูลโรงแรมจากฐานข้อมูล แสดงบนสุดของหน้าจอง
  Widget _hotelInfoCard() {
    final name = (_hotelInfo['name'] ?? _displayName).toString();
    final loc = (_hotelInfo['location'] ?? widget.hotel?.location ?? '').toString();
    final desc = (_hotelInfo['description'] ?? '').toString().trim();
    final rating = _toDouble(_hotelInfo['rating']);
    final tags = <String>[
      if (_flag(_hotelInfo['has_pool'])) 'สระว่ายน้ำ',
      if (_flag(_hotelInfo['has_breakfast'])) 'รวมอาหารเช้า',
      if (_flag(_hotelInfo['has_wifi'])) 'Wi‑Fi ฟรี',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const GradientIconBox(icon: Icons.apartment_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 15, color: AppColors.textSoft),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(loc, style: const TextStyle(color: AppColors.textSoft, fontSize: 13), overflow: TextOverflow.ellipsis),
                          ),
                          if (rating > 0) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
                            const SizedBox(width: 2),
                            Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(desc, style: const TextStyle(color: AppColors.textSoft, height: 1.5, fontSize: 13)),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) => AppChip(label: t, icon: Icons.check_circle_outline_rounded, accent: true)).toList(),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            InfoRow(icon: Icons.schedule_rounded, label: 'เวลาเช็คอิน', value: _time(['check_in_time', 'checkin_time'], '14:00')),
            InfoRow(icon: Icons.schedule_outlined, label: 'เวลาเช็คเอาต์', value: _time(['check_out_time', 'checkout_time'], '12:00')),
          ],
        ),
      ),
    );
  }

  String _roomName(Map<String, dynamic> r) =>
      (r['room_type'] ?? r['type_name'] ?? r['room_name'] ?? r['name'] ?? 'ห้องพัก').toString();

  Timer? _poll;
  Map<int, int> _avail = {}; // room_id -> ห้องว่างในช่วงวันที่ที่เลือก (นับเฉพาะห้องที่แอดมินยืนยันแล้ว)

  // ดึงจำนวนห้องว่างของแต่ละประเภทในช่วง เช็กอิน–เช็กเอาต์ ที่เลือก (คิดที่ server)
  Future<void> _loadAvail() async {
    final id = _dbHotelId;
    if (id == null || !mounted || _nights < 1) return;
    try {
      final data = await ApiService.getHotelById(id, checkIn: _fmtDb(_checkIn), checkOut: _fmtDb(_checkOut));
      if (!mounted) return;
      final map = <int, int>{};
      for (final r in (data['rooms'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(r);
        final rid = int.tryParse('${m['room_id']}');
        final left = int.tryParse('${m['rooms_available']}');
        if (rid != null && left != null) map[rid] = left;
      }
      setState(() => _avail = map);
    } catch (_) {} // เงียบ ๆ: รอบหน้าลองใหม่เอง
  }

  int? get _availNow {
    final r = _selectedRoom;
    if (r == null) return null;
    return _avail[int.tryParse('${r['room_id']}')];
  }

  // ห้องไม่พอสำหรับจำนวนที่เลือกในช่วงวันที่นั้น
  bool get _soldOut => _availNow != null && _availNow! < _numRooms;

  Widget _availBadge() {
    final n = _availNow!;
    final full = n <= 0;
    final notEnough = !full && n < _numRooms;
    final color = (full || notEnough) ? AppColors.danger : (n <= 3 ? AppColors.warning : AppColors.success);
    final text = full
        ? 'ห้องเต็มในช่วงวันที่เลือก'
        : (notEnough ? 'ห้องว่างไม่พอ เหลือ $n ห้องในช่วงวันที่เลือก' : 'ห้องว่างในช่วงวันที่เลือก: $n ห้อง');
    return Row(
      children: [
        Icon((full || notEnough) ? Icons.block_rounded : Icons.meeting_room_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13))),
      ],
    );
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final first = isCheckIn ? todayDate : _checkIn.add(const Duration(days: 1));
    final initial = isCheckIn ? _checkIn : _checkOut;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(today.year + 2, today.month, today.day),
    );
    if (picked == null) return;

    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (!_checkOut.isAfter(picked)) {
          _checkOut = picked.add(const Duration(days: 1));
        }
      } else {
        _checkOut = picked;
      }
    });
    _loadAvail();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRoom == null || _dbHotelId == null) {
      _showSnack('กรุณาเลือกห้องพัก');
      return;
    }
    if (_nights < 1) {
      _showSnack('วันเช็กเอาต์ต้องอยู่หลังวันเช็กอิน');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_bookingCode == null) {
        final result = await ApiService.createBooking({
          'hotelId': _dbHotelId,
          'roomId': _selectedRoom!['room_id'], // ชื่อ PK ของตาราง rooms
          'guestName': _nameCtrl.text.trim(),
          'guestEmail': _emailCtrl.text.trim(),
          'guestPhone': _phoneCtrl.text.trim(),
          'checkIn': _fmtDb(_checkIn),
          'checkOut': _fmtDb(_checkOut),
          'numRooms': _numRooms,
          'numGuests': _numGuests,
          'specialRequest': _requestCtrl.text.trim(),
          'totalAmount': _total,
        });
        _bookingCode = result['bookingCode']?.toString();
        _serverTotal = (result['totalAmount'] as num?)?.toDouble();
      }

      if (!mounted) return;
      _showSnack('บันทึกการจองแล้ว รหัส $_bookingCode');

      // บันทึกการจองแล้ว ไปหน้าชำระเงินทุกกรณี (ไม่ว่าจะเปิดจากหน้า Hotels หรือหน้ารายละเอียด)
      final hotelName = (_hotelInfo['name'] ?? _displayName).toString();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(hotelName: hotelName, total: (_serverTotal ?? _total).round(), bookingCode: _bookingCode),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('จองไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จองห้องพัก')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSoft),
              const SizedBox(height: 12),
              Text('โหลดข้อมูลไม่สำเร็จ\n$_loadError', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }

    if (_rooms.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        children: [
          _hotelInfoCard(),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('โรงแรมนี้ยังไม่มีห้องพักให้จอง', style: TextStyle(color: AppColors.textSoft))),
            ),
          ),
        ],
      );
    }


    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              children: [
                // ข้อมูลโรงแรมจากฐานข้อมูล
                _hotelInfoCard(),
                const SizedBox(height: 14),

                // วันที่เข้าพัก
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => _pickDate(isCheckIn: true),
                          borderRadius: BorderRadius.circular(12),
                          child: InfoRow(icon: Icons.calendar_month_rounded, label: 'เช็คอิน', value: _fmtShow(_checkIn)),
                        ),
                        InkWell(
                          onTap: () => _pickDate(isCheckIn: false),
                          borderRadius: BorderRadius.circular(12),
                          child: InfoRow(icon: Icons.event_rounded, label: 'เช็คเอาต์', value: _fmtShow(_checkOut)),
                        ),
                        InfoRow(icon: Icons.nights_stay_rounded, label: 'จำนวนคืน', value: '$_nights คืน'),
                        const SizedBox(height: 4),
                        const Text('แตะที่วันที่เพื่อเปลี่ยน', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _policyCard(),
                const SizedBox(height: 14),

                // ข้อมูลผู้จอง
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ข้อมูลผู้จอง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), labelText: 'ชื่อผู้จอง'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อผู้จอง' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'Email'),
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'กรุณากรอกอีเมล';
                            if (!s.contains('@') || !s.contains('.')) return 'รูปแบบอีเมลไม่ถูกต้อง';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined), labelText: 'เบอร์โทร'),
                          validator: (v) => (v == null || v.trim().length < 9) ? 'กรุณากรอกเบอร์โทรให้ถูกต้อง' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // รายละเอียดห้อง
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('รายละเอียดห้อง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedRoom,
                          isExpanded: true,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.bed_rounded), labelText: 'ประเภทห้อง'),
                          items: _rooms
                              .map((r) => DropdownMenuItem<Map<String, dynamic>>(
                                    value: r,
                                    child: Text('${_roomName(r)} • ${formatBaht(_unitPrice(r))}฿', overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedRoom = v;
                            _clampGuests();
                          }),
                        ),
                        if (_availNow != null) ...[
                          const SizedBox(height: 8),
                          _availBadge(),
                        ],
                        if (_selectedRoom != null && _roomDetail(_selectedRoom!).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(_roomDetail(_selectedRoom!), style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _numGuests,
                                isExpanded: true,
                                decoration: const InputDecoration(prefixIcon: Icon(Icons.people_alt_outlined), labelText: 'ผู้เข้าพัก'),
                                items: List.generate(_guestLimit, (i) => i + 1)
                                    .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n คน')))
                                    .toList(),
                                onChanged: (v) => setState(() => _numGuests = v ?? _numGuests),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _numRooms,
                                isExpanded: true,
                                decoration: const InputDecoration(prefixIcon: Icon(Icons.meeting_room_outlined), labelText: 'จำนวนห้อง'),
                                items: List.generate(5, (i) => i + 1)
                                    .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n ห้อง')))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _numRooms = v ?? _numRooms;
                                  _clampGuests();
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _requestCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.notes_rounded),
                            labelText: 'คำขอเพิ่มเติม',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ยอดรวม
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const GradientIconBox(icon: Icons.payments_rounded),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ยอดรวม', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                _numRooms > 1 ? '$_nights คืน × $_numRooms ห้อง' : '$_nights คืน',
                                style: const TextStyle(color: AppColors.textSoft, fontSize: 12),
                              ),
                              if (_deal != null)
                                Text(
                                  'ส่วนลดดีล "${_deal!['title']}" -${_deal!['discount_percent']}%',
                                  style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_deal != null && _originalTotal > _total)
                              Text('${formatBaht(_originalTotal)}฿', style: const TextStyle(color: AppColors.textSoft, fontSize: 12, decoration: TextDecoration.lineThrough)),
                            Text(
                              '${formatBaht(_total)}฿',
                              style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: (_submitting || _soldOut) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded),
              label: const Text('จองและไปชำระเงิน'),
            ),
          ),
        ),
      ],
    );
  }
}