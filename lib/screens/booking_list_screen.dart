import 'package:flutter/material.dart';

import '../api_service.dart';
import '../data/dummy_data.dart';
import '../models/booking_record.dart';
import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'booking_detail_screen.dart';

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  late Future<List<BookingRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getBookings();
  }

  Future<void> _reload() async {
    setState(() {
      _future = ApiService.getBookings();
    });
    await _future;
  }

  // หา Hotel (ข้อมูลเดิมของแอป) ที่ชื่อตรงกับการจอง ใช้สำหรับสีพื้นหลังการ์ด ถ้าไม่ตรงใช้โรงแรมแรก
  Hotel _hotelFor(BookingRecord b) {
    for (final h in hotels) {
      if (h.name == b.hotelName) return h;
    }
    return hotels.first;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: 3,
      title: 'ทริปของฉัน',
      child: FutureBuilder<List<BookingRecord>>(
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
                    const Icon(Icons.cloud_off, size: 48, color: AppColors.textSoft),
                    const SizedBox(height: 12),
                    Text(
                      'โหลดรายการจองไม่สำเร็จ\n${snapshot.error}'.replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('ลองใหม่')),
                  ],
                ),
              ),
            );
          }

          final bookings = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const AppSectionTitle(title: 'การจองของฉัน', subtitle: 'ติดตามสถานะการจองและรายละเอียดทริป'),
                const SizedBox(height: 14),
                if (bookings.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('ยังไม่มีรายการจอง', style: TextStyle(color: AppColors.textSoft))),
                    ),
                  ),
                for (final b in bookings) ...[
                  _BookingCard(
                    booking: b,
                    hotel: _hotelFor(b),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingDetailScreen(hotel: _hotelFor(b), total: b.total, booking: b),
                        ),
                      );
                      if (mounted) _reload();
                    },
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.hotel, required this.onTap});

  final BookingRecord booking;
  final Hotel hotel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = booking.isCancelled;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: hotelBannerDecoration(imageUrl: ApiService.imageUrl(booking.hotelImage), gradient: hotel.gradient, radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      booking.hotelName.isNotEmpty ? booking.hotelName : hotel.name,
                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text('รหัสการจอง: ${booking.code}', style: const TextStyle(color: Color(0xFFEAF1FF), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  AppChip(
                    label: booking.statusText,
                    icon: cancelled ? Icons.cancel_rounded : (booking.isPending ? (booking.hasSlip ? Icons.hourglass_top_rounded : Icons.payments_outlined) : Icons.check_circle_rounded),
                    accent: !cancelled && !booking.isPending,
                  ),
                  const Spacer(),
                  Text(booking.dateRangeText, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              InfoRow(icon: Icons.bed_rounded, label: 'ประเภทห้อง', value: booking.roomName),
              InfoRow(icon: Icons.people_alt_rounded, label: 'ผู้เข้าพัก', value: '${booking.numGuests} คน'),
            ],
          ),
        ),
      ),
    );
  }
}
