import 'package:flutter/material.dart';

import '../data/dummy_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'booking_detail_screen.dart';

class BookingListScreen extends StatelessWidget {
  const BookingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hotel = hotels.first;
    return AppShell(
      currentIndex: 3,
      title: 'Your trips',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const AppSectionTitle(title: 'My bookings', subtitle: 'ติดตามสถานะการจองและรายละเอียดทริป'),
          const SizedBox(height: 14),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(hotel: hotel, total: hotel.price * 2))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 120,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: hotel.gradient),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(hotel.name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Text('Booking ID: TN-0001', style: TextStyle(color: Color(0xFFEAF1FF), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        AppChip(label: 'ยืนยันแล้ว', icon: Icons.check_circle_rounded, accent: true),
                        Spacer(),
                        Text('20–22 Aug 2026', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const InfoRow(icon: Icons.bed_rounded, label: 'ประเภทห้อง', value: 'Deluxe Room'),
                    const InfoRow(icon: Icons.people_alt_rounded, label: 'ผู้เข้าพัก', value: '2 คน'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
            child: const Row(
              children: [
                GradientIconBox(icon: Icons.info_outline_rounded),
                SizedBox(width: 14),
                Expanded(child: Text('ข้อมูลการจองในหน้านี้เป็น Dummy Data เพื่อสาธิตหน้าตาและ Flow ของแอป', style: TextStyle(color: AppColors.textSoft))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
