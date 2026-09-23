import 'package:flutter/material.dart';

import '../data/dummy_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'hotel_detail_screen.dart';
import 'hotel_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: 0,
      title: 'Hotel booking made easy',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.primary, AppColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Where do you want to stay?', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
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
                Row(
                  children: [
                    Expanded(
                      child: _QuickField(
                        icon: Icons.calendar_month_rounded,
                        label: 'Check-in',
                        value: '20 Aug',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickField(
                        icon: Icons.people_alt_rounded,
                        label: 'Guests',
                        value: '2 guests',
                        onTap: () {},
                      ),
                    ),
                  ],
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
          const AppSectionTitle(title: 'Explore', subtitle: 'เลือกสไตล์การเข้าพักที่คุณชอบ'),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _CategoryCard(icon: Icons.local_offer_rounded, title: 'Deals', subtitle: 'ดีลพิเศษ'),
                SizedBox(width: 10),
                _CategoryCard(icon: Icons.beach_access_rounded, title: 'Beach', subtitle: 'ติดทะเล'),
                SizedBox(width: 10),
                _CategoryCard(icon: Icons.location_city_rounded, title: 'City', subtitle: 'ใจกลางเมือง'),
                SizedBox(width: 10),
                _CategoryCard(icon: Icons.terrain_rounded, title: 'Nature', subtitle: 'ใกล้ธรรมชาติ'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AppSectionTitle(
            title: 'Featured stays',
            subtitle: 'โรงแรมยอดนิยมที่กำลังได้รับความสนใจ',
            trailing: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HotelListScreen())),
              child: const Text('ดูทั้งหมด'),
            ),
          ),
          const SizedBox(height: 12),
          for (final hotel in hotels.take(3)) ...[
            HotelCard(
              hotel: hotel,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel))),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.12)),
            ),
            child: const Row(
              children: [
                GradientIconBox(icon: Icons.verified_user_rounded),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frontend Demo', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                      SizedBox(height: 4),
                      Text('หน้าจอและการกดเปลี่ยนหน้าทำงานแล้ว แต่ยังไม่เชื่อม Backend หรือ Database', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickField extends StatelessWidget {
  const _QuickField({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 11)),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 115,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
          Text(subtitle, style: const TextStyle(color: AppColors.textSoft, fontSize: 11)),
        ],
      ),
    );
  }
}
