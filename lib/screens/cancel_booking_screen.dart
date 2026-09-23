import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'booking_list_screen.dart';

class CancelBookingScreen extends StatefulWidget {
  const CancelBookingScreen({super.key, required this.hotelName});

  final String hotelName;

  @override
  State<CancelBookingScreen> createState() => _CancelBookingScreenState();
}

class _CancelBookingScreenState extends State<CancelBookingScreen> {
  String reason = 'เปลี่ยนแผนการเดินทาง';

  @override
  Widget build(BuildContext context) {
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
                    Text(widget.hotelName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const SizedBox(height: 8),
                    const Text('Booking ID: TN-0001 • Deluxe Room • 2 คืน', style: TextStyle(color: AppColors.textSoft)),
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
                    const Text('เหตุผลในการยกเลิก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
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
                    const TextField(maxLines: 3, decoration: InputDecoration(labelText: 'รายละเอียดเพิ่มเติม', alignLabelWithHint: true)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.07), borderRadius: BorderRadius.circular(20)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.danger),
                  SizedBox(width: 10),
                  Expanded(child: Text('นี่เป็น Frontend Demo การกดยืนยันจะไม่ลบข้อมูลจริงจากระบบ', style: TextStyle(color: AppColors.textSoft))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยกเลิกการจองแล้ว (Frontend Demo)')));
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const BookingListScreen()), (route) => false);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('ยืนยันการยกเลิก'),
            ),
          ],
        ),
      ),
    );
  }
}
