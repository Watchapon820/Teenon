import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models/hotel_filter.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'hotel_api_detail_screen.dart';

// ชุดสีไล่เฉดของการ์ด วนใช้ตาม hotel_id เพื่อให้แต่ละโรงแรมได้สีเดิมทุกครั้ง
const List<List<Color>> hotelGradients = [
  [Color(0xFF2F63C4), Color(0xFF4F93EE)], // น้ำเงิน
  [Color(0xFF2E9C7C), Color(0xFF5DBE9E)], // เขียวมิ้นต์
  [Color(0xFF6A57C9), Color(0xFF8E7CE0)], // ม่วง
  [Color(0xFFB83A68), Color(0xFFE56A97)], // ชมพู
  [Color(0xFFD9861C), Color(0xFFF2A33A)], // เหลืองมัสตาร์ด
  [Color(0xFFD9503A), Color(0xFFF4694F)], // โคอรัล
  [Color(0xFF2F6B4F), Color(0xFF5DA37F)], // เขียวเข้ม
];

class HotelListScreen extends StatefulWidget {
  // คำค้นหาที่ส่งมาจากหน้า home (ไม่ส่งมาก็ได้)
  final String initialQuery;

  // หมวดหมู่จากหน้า Home: deals | beach | city | nature (ไม่ส่งมาก็ได้)
  final String? initialCategory;

  const HotelListScreen({super.key, this.initialQuery = '', this.initialCategory});

  @override
  State<HotelListScreen> createState() => _HotelListScreenState();
}

class _HotelListScreenState extends State<HotelListScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<int> _saved = {};
  late final TextEditingController _search = TextEditingController(text: widget.initialQuery);
  final HotelFilter _filter = HotelFilter();

  Timer? _timer;
  List<Map<String, dynamic>>? _live; // รายการโรงแรมที่อัปเดตเงียบ ๆ (ห้องว่าง/ดีล)

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _filter.category = widget.initialCategory;
    _future = ApiService.getHotels();
    _loadSaved();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshLive());
  }

  Future<void> _refreshLive() async {
    try {
      final list = await ApiService.getHotels();
      if (mounted) setState(() => _live = list);
    } catch (_) {} // เงียบ ๆ: รอบหน้าลองใหม่เอง
  }

  // โหลดรายการโรงแรมที่กดดาวไว้ (ถ้าโหลดไม่ได้ก็แสดงดาวว่างไว้ก่อน)
  Future<void> _loadSaved() async {
    try {
      final list = await ApiService.getSavedHotels();
      if (!mounted) return;
      setState(() {
        _saved
          ..clear()
          ..addAll(list.map((h) => int.tryParse('${h['hotel_id']}') ?? -1));
      });
    } catch (_) {}
  }

  Future<void> _toggleSaved(int id) async {
    final nowSaved = !_saved.contains(id);
    setState(() => nowSaved ? _saved.add(id) : _saved.remove(id));
    try {
      await ApiService.setHotelSaved(id, nowSaved);
    } catch (e) {
      if (!mounted) return;
      setState(() => nowSaved ? _saved.remove(id) : _saved.add(id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _reload() async {
    setState(() {
      _live = null;
      _future = ApiService.getHotels();
    });
    _loadSaved();
    await _future;
  }

  // ย้อนกลับหน้าก่อนหน้า ถ้าไม่มีหน้าให้ย้อน (เช่น มาจากแท็บล่าง) ให้กลับหน้า Home
  void _goBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  // MySQL มักส่ง DECIMAL กลับมาเป็นสตริง จึงแปลงให้ปลอดภัย
  double _toDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  bool _flag(dynamic v) => v == true || v == 1 || v?.toString() == '1' || v?.toString() == 'true';

  // บรรทัดเล็กใต้ชื่อโรงแรม: สร้างจากสิ่งอำนวยความสะดวก ถ้าไม่มีข้อมูลใช้คำอธิบายแทน
  String _subtitleOf(Map<String, dynamic> h) {
    final tags = <String>[];
    if (_flag(h['has_pool'])) tags.add('สระว่ายน้ำ');
    if (_flag(h['has_breakfast'])) tags.add('รวมอาหารเช้า');
    if (_flag(h['has_wifi'])) tags.add('Wi‑Fi ฟรี');
    if (tags.isNotEmpty) return tags.join(' • ');
    return (h['description'] ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {

    // AppShell = แถบเมนูด้านล่าง (taskbar) เหมือนหน้าอื่นในแอป
    // currentIndex: 1 = แท็บโรงแรม/ค้นหา ถ้าลำดับแท็บในแอปคุณต่างไปให้แก้เลขนี้
    return AppShell(
      currentIndex: 1,
      title: 'โรงแรม',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'ย้อนกลับ',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _goBack,
                ),
                Expanded(
                  child: AppSectionTitle(
                    title: 'โรงแรมทั้งหมด',
                    subtitle: _filter.category != null
                        ? 'หมวด: ${hotelCategoryTitles[_filter.category] ?? ''}'
                        : 'เลือกโรงแรมที่ต้องการจอง',
                  ),
                ),
              ],
            ),
          ),
          _searchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _searchBar() {
    final n = _filter.activeCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อโรงแรม หรือจังหวัด',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: n > 0,
            label: Text('$n'),
            child: IconButton.filledTonal(
              tooltip: 'ตัวกรองและเรียงลำดับ',
              onPressed: _openFilters,
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final f = _filter;
    var maxPrice = f.maxPrice ?? 10000;
    var priceOn = f.maxPrice != null;
    var minRating = f.minRating;
    var pool = f.pool, breakfast = f.breakfast, wifi = f.wifi;
    var sort = f.sort;
    var category = f.category;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ตัวกรองและเรียงลำดับ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 14),
                const Text('หมวดหมู่', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in hotelCategoryTitles.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: category == e.key,
                        onSelected: (v) => setSheet(() => category = v ? e.key : null),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(child: Text('ราคาต่อคืนไม่เกิน', style: TextStyle(fontWeight: FontWeight.w800))),
                    Switch(value: priceOn, onChanged: (v) => setSheet(() => priceOn = v)),
                  ],
                ),
                Slider(
                  value: maxPrice.clamp(500, 10000).toDouble(),
                  min: 500,
                  max: 10000,
                  divisions: 19,
                  label: '${maxPrice.round()}฿',
                  onChanged: priceOn ? (v) => setSheet(() => maxPrice = v) : null,
                ),
                if (priceOn) Text('${maxPrice.round()}฿ / คืน', style: const TextStyle(color: AppColors.textSoft)),
                const SizedBox(height: 10),
                const Text('คะแนนขั้นต่ำ', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in [0.0, 3.5, 4.0, 4.5])
                      ChoiceChip(
                        label: Text(r == 0 ? 'ทั้งหมด' : '${r.toStringAsFixed(1)}+ ★'),
                        selected: minRating == r,
                        onSelected: (_) => setSheet(() => minRating = r),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('สิ่งอำนวยความสะดวก', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(label: const Text('สระว่ายน้ำ'), selected: pool, onSelected: (v) => setSheet(() => pool = v)),
                    FilterChip(label: const Text('รวมอาหารเช้า'), selected: breakfast, onSelected: (v) => setSheet(() => breakfast = v)),
                    FilterChip(label: const Text('Wi‑Fi ฟรี'), selected: wifi, onSelected: (v) => setSheet(() => wifi = v)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('เรียงตาม', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in const {
                      HotelSort.recommended: 'แนะนำ',
                      HotelSort.priceLow: 'ราคาต่ำ → สูง',
                      HotelSort.priceHigh: 'ราคาสูง → ต่ำ',
                      HotelSort.ratingHigh: 'คะแนนสูงสุด',
                    }.entries)
                      ChoiceChip(label: Text(e.value), selected: sort == e.key, onSelected: (_) => setSheet(() => sort = e.key)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          category = null;
                          priceOn = false;
                          minRating = 0;
                          pool = breakfast = wifi = false;
                          sort = HotelSort.recommended;
                        }),
                        child: const Text('ล้างทั้งหมด'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ค้นหา'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply != true) return;
    setState(() {
      f.category = category;
      f.maxPrice = priceOn ? maxPrice : null;
      f.minRating = minRating;
      f.pool = pool;
      f.breakfast = breakfast;
      f.wifi = wifi;
      f.sort = sort;
    });
  }

  Widget _buildList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('ลองใหม่'),
                  ),
                ],
              ),
            ),
          );
        }

        final all = _live ?? snapshot.data ?? [];
        final hotels = _filter.apply(all, _search.text);

        if (hotels.isEmpty) {
          return Center(
            child: Text(
              all.isEmpty
                  ? 'ยังไม่มีข้อมูลโรงแรม'
                  : (_filter.category == 'deals' && !all.any((h) => h['deal'] != null)
                      ? 'ยังไม่มีดีลพิเศษในขณะนี้\nกลับมาดูใหม่เร็ว ๆ นี้นะ'
                      : 'ไม่พบโรงแรมที่ตรงกับเงื่อนไข ลองปรับตัวกรองหรือคำค้นหา'),
              textAlign: TextAlign.center,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: hotels.length,
            itemBuilder: (context, i) {
              final h = hotels[i];
              final id = int.tryParse(h['hotel_id'].toString()) ?? i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: HotelApiCard(
                  name: h['name']?.toString() ?? '-',
                  location: h['location']?.toString() ?? '',
                  subtitle: _subtitleOf(h),
                  rating: _toDouble(h['rating']),
                  price: _toDouble(h['starting_price']),
                  gradient: hotelGradients[id % hotelGradients.length],
                  imageUrl: ApiService.imageUrl(h['image_url']),
                  roomsAvailable: roomsAvailableOf(h),
                  dealPercent: dealPercentOf(h),
                  dealPrice: dealPriceOf(h),
                  saved: _saved.contains(id),
                  onToggleSaved: () => _toggleSaved(id),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HotelApiDetailScreen(
                          hotelId: id,
                          hotelName: h['name']?.toString() ?? '',
                          gradient: hotelGradients[id % hotelGradients.length],
                        ),
                      ),
                    );
                    if (mounted) _loadSaved();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// การ์ดโรงแรมหน้าตาเดียวกับ HotelCard ในหน้า Home แต่ใช้ข้อมูลจาก API
class HotelApiCard extends StatelessWidget {
  const HotelApiCard({
    super.key,
    required this.name,
    required this.location,
    required this.subtitle,
    required this.rating,
    required this.price,
    required this.gradient,
    this.imageUrl,
    this.roomsAvailable,
    this.dealPercent,
    this.dealPrice,
    this.saved = false,
    this.onToggleSaved,
    required this.onTap,
  });

  final String name;
  final String location;
  final String subtitle;
  final double rating;
  final double price;
  final List<Color> gradient;
  final String? imageUrl;

  /// จำนวนห้องว่างของโรงแรม (คืนนี้) — null = ไม่แสดง
  final int? roomsAvailable;

  /// ดีลที่ใช้ได้ตอนนี้: ส่วนลด % และราคาเริ่มต้นหลังลด (null = ไม่มีดีล)
  final int? dealPercent;
  final double? dealPrice;
  final bool saved;
  final VoidCallback? onToggleSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                height: 132,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  image: imageUrl == null
                      ? null
                      : DecorationImage(
                          image: NetworkImage(imageUrl!),
                          fit: BoxFit.cover,
                          colorFilter: const ColorFilter.mode(Colors.black38, BlendMode.darken),
                        ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: onToggleSaved == null
                          ? const Icon(Icons.bed_rounded, size: 56, color: Colors.white38)
                          : Material(
                              color: Colors.black26,
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: saved ? 'เอาออกจากรายการที่บันทึก' : 'บันทึกโรงแรมนี้',
                                onPressed: onToggleSaved,
                                icon: Icon(
                                  saved ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 30,
                                  color: saved ? const Color(0xFFFFC83D) : Colors.white,
                                ),
                              ),
                            ),
                    ),
                    if (dealPercent != null)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_offer_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('ลด $dealPercent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFEAF1FF), fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: AppColors.textSoft),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFF5A623)),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (price > 0) ...[
                    const SizedBox(width: 8),
                    if (dealPrice != null) ...[
                      Text(
                        '${formatBaht(price)}฿',
                        style: const TextStyle(color: AppColors.textSoft, fontSize: 12, decoration: TextDecoration.lineThrough),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '${formatBaht(dealPrice ?? price)}฿',
                      style: TextStyle(color: dealPrice != null ? AppColors.danger : AppColors.navy, fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const Text('/คืน', style: TextStyle(color: AppColors.textSoft, fontSize: 11)),
                  ],
                ],
              ),
              if (roomsAvailable != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: _AvailabilityChip(count: roomsAvailable!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// จำนวนห้องว่างจากข้อมูลโรงแรมของ API (null ถ้า server ไม่ได้ส่งมา)
int? roomsAvailableOf(Map<String, dynamic> h) => int.tryParse('${h['rooms_available']}');

/// ส่วนลด % ของดีลที่ใช้ได้ตอนนี้ (null ถ้าโรงแรมไม่มีดีล)
int? dealPercentOf(Map<String, dynamic> h) => h['deal'] is Map ? int.tryParse('${(h['deal'] as Map)['discount_percent']}') : null;

/// ราคาเริ่มต้นหลังหักส่วนลด (null ถ้าไม่มีดีล)
double? dealPriceOf(Map<String, dynamic> h) => h['deal'] is Map ? double.tryParse('${h['deal_price']}') : null;

/// ป้ายบอกจำนวนห้องว่าง: เขียว = ยังว่าง, ส้ม = เหลือน้อย (≤ 3), แดง = เต็ม
class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final full = count <= 0;
    final low = !full && count <= 3;
    final color = full ? AppColors.danger : (low ? AppColors.warning : AppColors.success);
    final text = full ? 'ห้องเต็ม' : (low ? 'เหลือเพียง $count ห้อง' : 'ห้องว่าง $count ห้อง');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(full ? Icons.block_rounded : Icons.meeting_room_rounded, size: 15, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}
