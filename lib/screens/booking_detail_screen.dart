import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models/booking_record.dart';
import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'cancel_booking_screen.dart';
import 'payment_screen.dart';
import 'review_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.hotel, required this.total, this.booking});

  final Hotel hotel;
  final int total;

  /// ข้อมูลการจองจริงจากฐานข้อมูล ถ้าไม่ส่งมาจะแสดงข้อมูลตัวอย่างเหมือนเดิม
  final BookingRecord? booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final cancelled = b?.isCancelled ?? false;
    final hotelName = (b != null && b.hotelName.isNotEmpty) ? b.hotelName : hotel.name;

    return Scaffold(
      appBar: AppBar(title: const Text('สรุปการจอง')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: hotelBannerDecoration(imageUrl: ApiService.imageUrl(b?.hotelImage), gradient: hotel.gradient, radius: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppChip(
                    label: b?.statusText ?? 'ยืนยันแล้ว',
                    icon: cancelled ? Icons.cancel_rounded : ((b?.isPending ?? false) ? Icons.hourglass_top_rounded : Icons.verified_rounded),
                    accent: !cancelled && !(b?.isPending ?? false),
                  ),
                  const SizedBox(height: 18),
                  Text(hotelName, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('รหัสการจอง: ${b?.code ?? 'TN-0001'}', style: const TextStyle(color: Color(0xFFEAF1FF))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    InfoRow(icon: Icons.person_rounded, label: 'ชื่อผู้จอง', value: b?.guestName ?? 'Demo User'),
                    InfoRow(icon: Icons.calendar_month_rounded, label: 'เช็คอิน', value: b?.checkInText ?? '20 ส.ค. 2026'),
                    InfoRow(icon: Icons.event_rounded, label: 'เช็คเอาต์', value: b?.checkOutText ?? '22 ส.ค. 2026'),
                    InfoRow(icon: Icons.bed_rounded, label: 'ห้อง', value: b?.roomName ?? 'Deluxe Room'),
                    InfoRow(icon: Icons.people_alt_rounded, label: 'ผู้เข้าพัก', value: '${b?.numGuests ?? 2} คน'),
                    InfoRow(icon: Icons.payments_rounded, label: 'ยอดชำระ', value: '${b?.total ?? total}฿'),
                    if (b != null && !cancelled)
                      InfoRow(
                        icon: Icons.receipt_long_rounded,
                        label: 'การชำระเงิน',
                        value: b.isPending ? (b.hasSlip ? 'ส่งสลิปแล้ว รอตรวจสอบ' : 'ยังไม่ได้ชำระเงิน') : 'ได้รับการยืนยันแล้ว',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (b != null && b.awaitingPayment) ...[
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PaymentScreen(hotelName: hotelName, total: b.total, bookingCode: b.code)),
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('ชำระเงิน / ส่งสลิป'),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // รีวิวได้เมื่อยืนยันแล้ว + ถึงวันเข้าพัก + ยังไม่เคยรีวิว
                    onPressed: (b != null && b.canReview)
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ReviewScreen(hotelName: hotelName, bookingCode: b.code)),
                            )
                        : null,
                    icon: const Icon(Icons.rate_review_rounded),
                    label: Text(b != null && b.hasReview ? 'รีวิวแล้ว' : 'เขียนรีวิว'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    // การจองที่ยกเลิกแล้ว หรือเลยกำหนดยกเลิกตามนโยบาย กดไม่ได้
                    onPressed: (cancelled || b?.cancelBlock != null)
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CancelBookingScreen(hotelName: hotelName, booking: b)),
                            ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(cancelled ? 'ยกเลิกแล้ว' : (b?.cancelBlock != null ? 'ยกเลิกไม่ได้' : 'ยกเลิกการจอง')),
                  ),
                ),
              ],
            ),
            if (!cancelled && b?.cancelBlock != null) ...[
              const SizedBox(height: 8),
              Text(b!.cancelBlock!, style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
