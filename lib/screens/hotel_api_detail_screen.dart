import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'booking_screen.dart';

/// หน้ารายละเอียดโรงแรมที่ดึงข้อมูลจริงจากฐานข้อมูล (ทุกโรงแรมใช้หน้านี้เหมือนกัน)
/// กดปุ่ม "จองห้องพัก" แล้วจึงไปหน้า BookingScreen
class HotelApiDetailScreen extends StatefulWidget {
  const HotelApiDetailScreen({
    super.key,
    required this.hotelId,
    required this.hotelName,
    required this.gradient,
  });

  final int hotelId;
  final String hotelName;
  final List<Color> gradient;

  @override
  State<HotelApiDetailScreen> createState() => _HotelApiDetailScreenState();
}

class _HotelApiDetailScreenState extends State<HotelApiDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  late Future<Map<String, dynamic>> _reviews;
  bool saved = false;
  final PageController _pager = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getHotelById(widget.hotelId);
    _reviews = ApiService.getHotelReviews(widget.hotelId);
    _loadSaved();
    // ห้องว่างเปลี่ยนเมื่อแอดมินกดยืนยันการจอง → ดึงข้อมูลใหม่เองทุก 8 วินาที (ไม่กระพริบ)
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshLive());
  }

  Timer? _timer;
  Map<String, dynamic>? _live;

  Future<void> _refreshLive() async {
    try {
      final d = await ApiService.getHotelById(widget.hotelId);
      if (mounted) setState(() => _live = d);
    } catch (_) {} // เงียบ ๆ: รอบหน้าลองใหม่เอง
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  // ดาว/หัวใจ: อ่านสถานะที่บันทึกไว้ของผู้ใช้จากฐานข้อมูล
  Future<void> _loadSaved() async {
    try {
      final list = await ApiService.getSavedHotels();
      if (!mounted) return;
      setState(() => saved = list.any((h) => '${h['hotel_id']}' == '${widget.hotelId}'));
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    final next = !saved;
    setState(() => saved = next);
    try {
      await ApiService.setHotelSaved(widget.hotelId, next);
    } catch (e) {
      if (!mounted) return;
      setState(() => saved = !next);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _reload() {
    setState(() {
      _live = null;
      _future = ApiService.getHotelById(widget.hotelId);
      _reviews = ApiService.getHotelReviews(widget.hotelId);
    });
  }

  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  bool _flag(dynamic v) => v == true || v == 1 || v?.toString() == '1' || v?.toString() == 'true';

  // เวลาจาก MySQL เป็น "14:00:00" ตัดวินาทีออกให้เหลือ "14:00"
  String _time(dynamic v, String fallback) {
    final s = v?.toString() ?? '';
    if (s.isEmpty) return fallback;
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  // รองรับหลายชื่อคอลัมน์ เผื่อชื่อใน DB ต่างกัน
  dynamic _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m[k] != null) return m[k];
    }
    return null;
  }

  String _roomName(Map<String, dynamic> r) =>
      (r['room_type'] ?? r['type_name'] ?? r['room_name'] ?? r['name'] ?? 'ห้องพัก').toString();

  void _goBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(hotelId: widget.hotelId, hotelName: widget.hotelName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดโรงแรม'),
        actions: [
          IconButton(
            onPressed: _toggleSaved,
            icon: Icon(saved ? Icons.star_rounded : Icons.star_border_rounded, size: 30, color: saved ? const Color(0xFFFFC83D) : null),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSoft),
                      const SizedBox(height: 12),
                      Text(
                        'โหลดข้อมูลโรงแรมไม่สำเร็จ\n${snapshot.error}'.replaceAll('Exception: ', ''),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _reload, child: const Text('ลองใหม่')),
                    ],
                  ),
                ),
              );
            }
            return _buildContent(_live ?? snapshot.data ?? {});
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    // บางแบบ API ส่งข้อมูลโรงแรมซ้อนใน 'hotel' บางแบบส่งที่ระดับบนสุด
    final Map<String, dynamic> h =
        data['hotel'] is Map ? Map<String, dynamic>.from(data['hotel']) : data;
    final rooms = (data['rooms'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

    final name = (h['name'] ?? widget.hotelName).toString();
    final location = (h['location'] ?? '').toString();
    final description = (h['description'] ?? '').toString().trim();
    final rating = _toDouble(h['rating']);
    final reviewCount = int.tryParse('${h['review_count']}') ?? 0;
    final images = <String>[
      if (ApiService.imageUrl(h['image_url']) != null) ApiService.imageUrl(h['image_url'])!,
      ...((data['images'] as List?) ?? []).map((e) => ApiService.imageUrl(e)).whereType<String>(),
    ];
    final checkIn = _time(_pick(h, ['check_in_time', 'checkin_time', 'check_in']), '14:00');
    final checkOut = _time(_pick(h, ['check_out_time', 'checkout_time', 'check_out']), '12:00');
    final hasPool = _flag(h['has_pool']);
    final hasBreakfast = _flag(h['has_breakfast']);
    final hasWifi = _flag(h['has_wifi']);
    // ดีลที่ใช้ได้ตอนนี้ + ราคาห้องถูกสุดหลังลด (ไว้แสดงที่แถบราคาด้านล่าง)
    final deal = data['deal'] is Map ? Map<String, dynamic>.from(data['deal']) : null;
    double? dealMin;
    if (deal != null) {
      final ps = rooms.map((r) => _toDouble(r['deal_price'])).where((p) => p > 0).toList()..sort();
      if (ps.isNotEmpty) dealMin = ps.first;
    }

    double minPrice = _toDouble(h['starting_price']);
    if (minPrice <= 0 && rooms.isNotEmpty) {
      final prices = rooms.map((r) => _toDouble(r['price_per_night'])).where((p) => p > 0).toList();
      if (prices.isNotEmpty) {
        prices.sort();
        minPrice = prices.first;
      }
    }

    final tags = <String>[
      if (hasPool) 'สระว่ายน้ำ',
      if (hasBreakfast) 'รวมอาหารเช้า',
      if (hasWifi) 'Wi‑Fi ฟรี',
      ...((data['tags'] as List?) ?? []).map((e) => e.toString()),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            children: [
              _hero(h, name, location, rating, reviewCount, images),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((t) => AppChip(label: t, icon: Icons.check_circle_outline_rounded, accent: true)).toList(),
                ),
              ],
              if (deal != null) ...[
                const SizedBox(height: 14),
                _dealBanner(deal),
              ],
              const SizedBox(height: 22),
              const AppSectionTitle(title: 'เกี่ยวกับโรงแรม', subtitle: 'รายละเอียดและสิ่งอำนวยความสะดวก'),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (description.isNotEmpty) ...[
                        Text(description, style: const TextStyle(color: AppColors.textSoft, height: 1.6)),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                      ],
                      InfoRow(icon: Icons.pool_rounded, label: 'สระว่ายน้ำ', value: hasPool ? 'มี' : 'ไม่มี'),
                      InfoRow(icon: Icons.restaurant_rounded, label: 'อาหารเช้า', value: hasBreakfast ? 'รวมแล้ว' : 'ไม่รวม'),
                      InfoRow(icon: Icons.wifi_rounded, label: 'Wi‑Fi', value: hasWifi ? 'ฟรี' : 'ไม่มี'),
                      InfoRow(icon: Icons.schedule_rounded, label: 'เช็คอิน', value: checkIn),
                      InfoRow(icon: Icons.schedule_outlined, label: 'เช็คเอาต์', value: checkOut),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _policyCard(h),
              const SizedBox(height: 18),
              const AppSectionTitle(title: 'ห้องพัก', subtitle: 'เลือกห้องให้เหมาะกับการเข้าพัก'),
              const SizedBox(height: 12),
              if (rooms.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('โรงแรมนี้ยังไม่มีห้องพักให้จอง', style: TextStyle(color: AppColors.textSoft)),
                  ),
                ),
              for (final r in rooms) _roomCard(r),
              const SizedBox(height: 8),
              _reviewsSection(),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ราคาเริ่มต้น', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                    if (dealMin != null && minPrice > 0)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${formatBaht(dealMin)}฿', style: const TextStyle(color: AppColors.danger, fontSize: 21, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          Text('${formatBaht(minPrice)}฿', style: const TextStyle(color: AppColors.textSoft, fontSize: 13, decoration: TextDecoration.lineThrough)),
                          const Text(' / คืน', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                        ],
                      )
                    else
                      Text(
                        minPrice > 0 ? '${formatBaht(minPrice)}฿ / คืน' : '-',
                        style: const TextStyle(color: AppColors.navy, fontSize: 21, fontWeight: FontWeight.w800),
                      ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: rooms.isEmpty ? null : _goBooking,
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('จองห้องพัก'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // แบนเนอร์ดีลของโรงแรม: ชื่อ ส่วนลด % และวันสุดท้ายที่ใช้ได้
  Widget _dealBanner(Map<String, dynamic> deal) {
    final end = '${deal['end_date'] ?? ''}';
    final desc = '${deal['description'] ?? ''}'.trim();
    final endText = end.length >= 10 ? ' • ถึงวันที่ ${end.substring(8, 10)}/${end.substring(5, 7)}/${end.substring(0, 4)}' : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(14)),
            child: Text('-${deal['discount_percent']}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${deal['title']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${desc.isEmpty ? 'ส่วนลดทุกประเภทห้อง' : desc}$endText', style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(int i) => _pager.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  // ปุ่มลูกศรเลื่อนรูป (ซ้าย/ขวา) — จางลงเมื่อสุดทางแล้ว
  Widget _arrow(IconData icon, String tooltip, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, color: Colors.white, size: 28)),
      ),
    );
  }

  Widget _hero(Map<String, dynamic> h, String name, String location, double rating, int reviewCount, List<String> images) {
    final overlay = Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.star_rounded, color: Color(0xFFFFC45C), size: 19),
                const SizedBox(width: 4),
                Text(
                  reviewCount > 0 ? '${rating.toStringAsFixed(1)} ($reviewCount รีวิว)' : rating.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 235,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            ),
            if (images.isNotEmpty)
              // ลากด้วยเมาส์/ทัชแพดได้ด้วย (เว็บและเดสก์ท็อปไม่เปิดให้ลากด้วยเมาส์เป็นค่าเริ่มต้น)
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus},
                ),
                child: PageView.builder(
                  controller: _pager,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              )
            else
              const Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(22), child: Icon(Icons.apartment_rounded, size: 120, color: Colors.white12))),
            if (images.isNotEmpty)
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.transparent, Colors.black54], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                ),
              ),
            IgnorePointer(child: overlay),
            if (images.length > 1) ...[
              Positioned(left: 6, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_left_rounded, 'รูปก่อนหน้า', _page > 0 ? () => _goTo(_page - 1) : null))),
              Positioned(right: 6, top: 0, bottom: 0, child: Center(child: _arrow(Icons.chevron_right_rounded, 'รูปถัดไป', _page < images.length - 1 ? () => _goTo(_page + 1) : null))),
              Positioned(
                left: 0,
                right: 0,
                top: 14,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < images.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(color: i == _page ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (images.length > 1)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14)),
                  child: Text('${_page + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _policyCard(Map<String, dynamic> h) {
    final days = int.tryParse('${h['free_cancel_days']}') ?? 3;
    final custom = '${h['cancellation_policy'] ?? ''}'.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_available_rounded, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('นโยบายการยกเลิก', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(
                    days <= 0 ? 'ยกเลิกได้ถึงวันเช็คอิน' : 'ยกเลิกฟรีก่อนวันเช็คอิน $days วัน',
                    style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                  ),
                  if (custom.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(custom, style: const TextStyle(color: AppColors.textSoft, fontSize: 13, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomCard(Map<String, dynamic> r) {
    final image = ApiService.imageUrl(r['image_url']);
    final left = int.tryParse('${r['rooms_available']}'); // ห้องว่างคืนนี้
    final dealPrice = _toDouble(r['deal_price']); // ราคาหลังหักส่วนลดดีล (0 = ไม่มีดีล)
    final details = <String>[
      if ('${r['bed_type'] ?? ''}'.isNotEmpty) '${r['bed_type']}',
      if (int.tryParse('${r['size_sqm']}') != null) '${r['size_sqm']} ตร.ม.',
      if (int.tryParse('${r['max_guests']}') != null) 'พักได้ ${r['max_guests']} คน',
      if (r['bed_type'] == null && _pick(r, ['max_guests', 'capacity']) == null) '',
    ].where((e) => e.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: image == null
                  ? Container(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: widget.gradient)),
                      child: const Icon(Icons.bed_rounded, color: Colors.white),
                    )
                  : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.bed_rounded)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_roomName(r), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(details.join(' • '), style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (dealPrice > 0)
                    Text('${formatBaht(_toDouble(r['price_per_night']))}฿', style: const TextStyle(color: AppColors.textSoft, fontSize: 12, decoration: TextDecoration.lineThrough)),
                  Text(
                    '${formatBaht(dealPrice > 0 ? dealPrice : _toDouble(r['price_per_night']))}฿',
                    style: TextStyle(color: dealPrice > 0 ? AppColors.danger : AppColors.navy, fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const Text('/คืน', style: TextStyle(color: AppColors.textSoft, fontSize: 11)),
                  if (left != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      left <= 0 ? 'ห้องเต็ม' : 'เหลือ $left ห้อง',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: left <= 0 ? AppColors.danger : (left <= 3 ? AppColors.warning : AppColors.success),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewsSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _reviews,
      builder: (context, snap) {
        final data = snap.data;
        final count = (data?['count'] as num?)?.toInt() ?? 0;
        final list = ((data?['data'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionTitle(title: 'รีวิวจากผู้เข้าพัก', subtitle: count > 0 ? '$count รีวิว' : 'ยังไม่มีรีวิว'),
            const SizedBox(height: 12),
            if (snap.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
            else if (list.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('เป็นคนแรกที่รีวิวโรงแรมนี้หลังเข้าพัก', style: TextStyle(color: AppColors.textSoft)))),
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('${r['user_name'] ?? 'ผู้เข้าพัก'}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text))),
                            ...List.generate(
                              5,
                              (i) => Icon(i < (int.tryParse('${r['rating']}') ?? 0) ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: const Color(0xFFF5A623)),
                            ),
                          ],
                        ),
                        if ('${r['comment'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('${r['comment']}', style: const TextStyle(color: AppColors.textSoft, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
