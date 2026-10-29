import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models/booking_record.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'booking_list_screen.dart';

class CancelBookingScreen extends StatefulWidget {
  const CancelBookingScreen({super.key, required this.hotelName, this.booking});

  final String hotelName;

  /// การจองที่จะยกเลิก (จากฐานข้อมูล) ถ้าไม่ส่งมาจะเป็นการยกเลิกตัวอย่างเหมือนเดิม
  final BookingRecord? booking;

  @override
  State<CancelBookingScreen> createState() => _CancelBookingScreenState();
}

class _CancelBookingScreenState extends State<CancelBookingScreen> {
  String reason = 'เปลี่ยนแผนการเดินทาง';
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmCancel() async {
    final b = widget.booking;
    setState(() => _submitting = true);
    try {
      // ยกเลิกในฐานข้อมูลจริง (ถ้าเป็นการจองจากฐานข้อมูล)
      if (b != null) {
        await ApiService.cancelBooking(b.code, reason: reason, details: _detailsCtrl.text.trim());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยกเลิกการจองแล้ว')));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BookingListScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ยกเลิกไม่สำเร็จ: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final summary = b != null
        ? 'Booking ID: ${b.code} • ${b.roomName} • ${b.nights} คืน'
        : 'Booking ID: TN-0001 • Deluxe Room • 2 คืน';

    return Scaffold(
      appBar: AppBar(title: const Text('Cancel booking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            const AppSectionTitle(title: 'ยกเลิกการจอง', subtitle: 'กรุณาตรวจสอบรายละเอียดก่อนยืนยัน'),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.hotelName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Text(summary, style: const TextStyle(color: AppColors.textSoft)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เหตุผลในการยกเลิก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 12),
                    ...['เปลี่ยนแผนการเดินทาง', 'เลือกที่พักอื่น', 'จองข้อมูลผิด', 'อื่น ๆ'].map((item) {
                      return RadioListTile<String>(
                        value: item,
                        groupValue: reason,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item),
                        onChanged: (value) => setState(() => reason = value ?? reason),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextField(controller: _detailsCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'รายละเอียดเพิ่มเติม', alignLabelWithHint: true)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: _submitting ? null : _confirmCancel,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline_rounded),
              label: const Text('ยืนยันการยกเลิก'),
            ),
          ],
        ),
      ),
    );
  }
}
