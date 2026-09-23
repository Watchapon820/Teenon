import 'package:flutter/material.dart';

import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'cancel_booking_screen.dart';
import 'review_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.hotel, required this.total});

  final Hotel hotel;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking summary')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: hotel.gradient),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppChip(label: 'ยืนยันแล้ว', icon: Icons.verified_rounded, accent: true),
                  const SizedBox(height: 18),
                  Text(hotel.name, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Booking ID: TN-0001', style: TextStyle(color: Color(0xFFEAF1FF))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const InfoRow(icon: Icons.person_rounded, label: 'ชื่อผู้จอง', value: 'Demo User'),
                    const InfoRow(icon: Icons.calendar_month_rounded, label: 'Check-in', value: '20 Aug 2026'),
                    const InfoRow(icon: Icons.event_rounded, label: 'Check-out', value: '22 Aug 2026'),
                    const InfoRow(icon: Icons.bed_rounded, label: 'ห้อง', value: 'Deluxe Room'),
                    const InfoRow(icon: Icons.people_alt_rounded, label: 'ผู้เข้าพัก', value: '2 คน'),
                    InfoRow(icon: Icons.payments_rounded, label: 'ยอดชำระ', value: '$total฿'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(hotelName: hotel.name))),
                    icon: const Icon(Icons.rate_review_rounded),
                    label: const Text('เขียนรีวิว'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CancelBookingScreen(hotelName: hotel.name))),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('ยกเลิกการจอง'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
