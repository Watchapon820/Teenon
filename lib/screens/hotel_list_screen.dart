import 'package:flutter/material.dart';

import '../data/dummy_data.dart';
import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'hotel_detail_screen.dart';

class HotelListScreen extends StatefulWidget {
  const HotelListScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<HotelListScreen> createState() => _HotelListScreenState();
}

class _HotelListScreenState extends State<HotelListScreen> {
  late final TextEditingController searchController;
  String selectedFilter = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Hotel> get filtered {
    final q = searchController.text.trim().toLowerCase();
    return hotels.where((hotel) {
      final matchesQuery = q.isEmpty || hotel.name.toLowerCase().contains(q) || hotel.location.toLowerCase().contains(q);
      final matchesFilter = selectedFilter == 'ทั้งหมด' ||
          (selectedFilter == 'กรุงเทพฯ' && hotel.location == 'กรุงเทพฯ') ||
          (selectedFilter == 'ริมทะเล' && hotel.tags.contains('ติดทะเล')) ||
          (selectedFilter == 'คะแนน 4.8+' && hotel.rating >= 4.8);
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = filtered;
    return AppShell(
      currentIndex: 1,
      title: 'Explore hotels',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ค้นหาโรงแรมหรือจังหวัด'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: ['ทั้งหมด', 'กรุงเทพฯ', 'ริมทะเล', 'คะแนน 4.8+'].map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selectedFilter == filter,
                    label: Text(filter),
                    onSelected: (_) => setState(() => selectedFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(icon: Icons.search_off_rounded, title: 'ไม่พบโรงแรม', subtitle: 'ลองเปลี่ยนคำค้นหาหรือตัวกรองอีกครั้ง')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final hotel = items[index];
                      return HotelCard(
                        hotel: hotel,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
