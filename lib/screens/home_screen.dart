import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'chat_screen.dart';
import 'contact_screen.dart';
import 'hotel_api_detail_screen.dart';
import 'hotel_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _featured;
  final Set<int> _saved = {};

  @override
  void initState() {
    super.initState();
    _featured = ApiService.getHotels();
    _loadSaved();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshLive());
  }

  Timer? _timer;
  List<Map<String, dynamic>>? _live; // รายการโรงแรมที่อัปเดตเงียบ ๆ (ห้องว่าง/ดีล)

  Future<void> _refreshLive() async {
    try {
      final list = await ApiService.getHotels();
      if (mounted) setState(() => _live = list);
    } catch (_) {} // เงียบ ๆ: รอบหน้าลองใหม่เอง
  }

  int _idOf(Map<String, dynamic> h) => int.tryParse('${h['hotel_id']}') ?? 0;
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  // โหลดรายการโรงแรมที่กดดาวไว้ (ถ้าโหลดไม่ได้ก็แสดงดาวว่างไว้ก่อน)
  Future<void> _loadSaved() async {
    try {
      final list = await ApiService.getSavedHotels();
      if (!mounted) return;
      setState(() {
        _saved
          ..clear()
          ..addAll(list.map(_idOf));
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

  Future<void> _openCategory(String category) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => HotelListScreen(initialCategory: category)));
    if (mounted) _loadSaved();
  }

  Widget _featuredList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _featured,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('โหลดโรงแรมไม่สำเร็จ\n${snap.error}'.replaceAll('Exception: ', ''), textAlign: TextAlign.center)),
          );
        }
        final list = List<Map<String, dynamic>>.of(_live ?? snap.data ?? [])
          ..sort((a, b) => _num(b['rating']).compareTo(_num(a['rating'])));
        return Column(
          children: [
            for (final h in list.take(3)) ...[
              HotelApiCard(
                key: ValueKey(_idOf(h)),
                name: h['name']?.toString() ?? '-',
                location: h['location']?.toString() ?? '',
                subtitle: (h['description'] ?? '').toString().trim(),
                rating: _num(h['rating']),
                price: _num(h['starting_price']),
                gradient: hotelGradients[_idOf(h) % hotelGradients.length],
                imageUrl: ApiService.imageUrl(h['image_url']),
                roomsAvailable: roomsAvailableOf(h),
                dealPercent: dealPercentOf(h),
                dealPrice: dealPriceOf(h),
                saved: _saved.contains(_idOf(h)),
                onToggleSaved: () => _toggleSaved(_idOf(h)),
                onTap: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HotelApiDetailScreen(
                        hotelId: _idOf(h),
                        hotelName: h['name']?.toString() ?? '',
                        gradient: hotelGradients[_idOf(h) % hotelGradients.length],
                      ),
                    ),
                  );
                  if (mounted) _loadSaved();
                },
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: 0,
      title: 'จองโรงแรมง่ายๆ ในแอปเดียว',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.coralLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('คุณอยากพักที่ไหน?', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('ค้นหาที่พักที่เหมาะกับทริปของคุณ', style: TextStyle(color: Colors.white.withOpacity(0.82))),
                const SizedBox(height: 18),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'โรงแรม จังหวัด หรือพื้นที่',
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelListScreen(initialQuery: searchController.text))),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelListScreen(initialQuery: searchController.text))),
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: const Text('ค้นหาโรงแรม'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const AppSectionTitle(title: 'เลือกสไตล์ที่พัก', subtitle: 'แตะเพื่อดูโรงแรมในหมวดที่คุณชอบ'),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryCard(color: AppColors.pink, icon: Icons.local_offer_rounded, title: 'ดีล', subtitle: 'ส่วนลดพิเศษ', onTap: () => _openCategory('deals')),
                const SizedBox(width: 10),
                _CategoryCard(color: AppColors.blue, icon: Icons.beach_access_rounded, title: 'ทะเล', subtitle: 'ติดทะเล', onTap: () => _openCategory('beach')),
                const SizedBox(width: 10),
                _CategoryCard(color: AppColors.purple, icon: Icons.location_city_rounded, title: 'ในเมือง', subtitle: 'ใจกลางเมือง', onTap: () => _openCategory('city')),
                const SizedBox(width: 10),
                _CategoryCard(color: AppColors.green, icon: Icons.terrain_rounded, title: 'ธรรมชาติ', subtitle: 'ใกล้ธรรมชาติ', onTap: () => _openCategory('nature')),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AppSectionTitle(
            title: 'โรงแรมแนะนำ',
            subtitle: 'โรงแรมยอดนิยมที่กำลังได้รับความสนใจ',
            trailing: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HotelListScreen())),
              child: const Text('ดูทั้งหมด'),
            ),
          ),
          const SizedBox(height: 12),
          _featuredList(),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ต้องการความช่วยเหลือ?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 6),
                const Text('ติดต่อทีมงานของเราได้ตลอดเวลา', style: TextStyle(color: AppColors.textSoft)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('แชทกับทีมงาน'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen())),
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('โทรหาเรา'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.color, required this.icon, required this.title, required this.subtitle, required this.onTap});

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
      width: 115,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    ),
    );
  }
}
