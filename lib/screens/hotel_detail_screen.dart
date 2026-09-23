import 'package:flutter/material.dart';

import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'booking_screen.dart';

class HotelDetailScreen extends StatefulWidget {
  const HotelDetailScreen({super.key, required this.hotel});

  final Hotel hotel;

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  bool saved = false;

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel detail'),
        actions: [
          IconButton(
            onPressed: () => setState(() => saved = !saved),
            icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: saved ? AppColors.danger : null),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  Container(
                    height: 235,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: hotel.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Stack(
                      children: [
                        const Align(alignment: Alignment.topRight, child: Icon(Icons.apartment_rounded, size: 120, color: Colors.white12)),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hotel.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.white70, size: 18),
                                  const SizedBox(width: 4),
                                  Text(hotel.location, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFC45C), size: 19),
                                  const SizedBox(width: 4),
                                  Text('${hotel.rating}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: hotel.tags.map((tag) => AppChip(label: tag, icon: Icons.check_circle_outline_rounded, accent: true)).toList(),
                  ),
                  const SizedBox(height: 22),
                  const AppSectionTitle(title: 'About this hotel', subtitle: 'รายละเอียดและสิ่งอำนวยความสะดวก'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'โรงแรมดีไซน์ทันสมัย บรรยากาศสบาย เหมาะสำหรับทั้งการพักผ่อนและท่องเที่ยว พร้อมสิ่งอำนวยความสะดวกครบครัน และเดินทางสะดวก',
                            style: const TextStyle(color: AppColors.textSoft, height: 1.6),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          const InfoRow(icon: Icons.pool_rounded, label: 'สระว่ายน้ำ', value: 'มี'),
                          const InfoRow(icon: Icons.restaurant_rounded, label: 'อาหารเช้า', value: 'รวมแล้ว'),
                          const InfoRow(icon: Icons.wifi_rounded, label: 'Wi‑Fi', value: 'ฟรี'),
                          const InfoRow(icon: Icons.schedule_rounded, label: 'Check-in', value: '14:00'),
                          const InfoRow(icon: Icons.schedule_outlined, label: 'Check-out', value: '12:00'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const AppSectionTitle(title: 'Room options', subtitle: 'เลือกห้องให้เหมาะกับการเข้าพัก'),
                  const SizedBox(height: 12),
                  ...[
                    ('Deluxe Room', '1 King Bed • 2 guests', hotel.price),
                    ('Double Room', '2 Double Beds • 4 guests', hotel.price + 450),
                    ('Master Room', '1 King + 2 Double • 7 guests', hotel.price + 1200),
                  ].map((room) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const GradientIconBox(icon: Icons.bed_rounded),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(room.$1, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                                    const SizedBox(height: 4),
                                    Text(room.$2, style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text('${room.$3}฿', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 17)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const AppSectionTitle(title: 'Guest reviews', subtitle: 'ความคิดเห็นตัวอย่างจากผู้เข้าพัก'),
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(child: Text('A')),
                              SizedBox(width: 12),
                              Expanded(child: Text('Anan • ★ 5.0', style: TextStyle(fontWeight: FontWeight.w800))),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text('ห้องสะอาด บริการดี เดินทางสะดวก และอาหารเช้าอร่อยมาก', style: TextStyle(color: AppColors.textSoft)),
                        ],
                      ),
                    ),
                  ),
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
                        const Text('Starting from', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                        Text('${hotel.price}฿ / คืน', style: const TextStyle(color: AppColors.navy, fontSize: 21, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(hotel: hotel))),
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('จองห้องพัก'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
