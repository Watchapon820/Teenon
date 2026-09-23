import 'package:flutter/material.dart';

import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'booking_detail_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.hotel, required this.total});

  final Hotel hotel;
  final int total;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String method = 'QR Payment';
  bool slipAttached = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            const AppSectionTitle(title: 'ชำระเงิน', subtitle: 'เลือกช่องทางการชำระเงินเพื่อยืนยันการจอง'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.navy, AppColors.primary]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ยอดชำระทั้งหมด', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text('${widget.total}฿', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(widget.hotel.name, style: const TextStyle(color: Color(0xFFE7EEFF), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ช่องทางชำระเงิน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const SizedBox(height: 12),
                    ...['QR Payment', 'Credit / Debit Card', 'Bank Transfer'].map((item) {
                      return RadioListTile<String>(
                        value: item,
                        groupValue: method,
                        onChanged: (value) => setState(() => method = value ?? method),
                        contentPadding: EdgeInsets.zero,
                        title: Text(item, style: const TextStyle(fontWeight: FontWeight.w700)),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (method == 'QR Payment')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded, size: 110, color: AppColors.navy),
                            SizedBox(height: 6),
                            Text('DEMO QR', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSoft)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('QR นี้เป็นเพียงตัวอย่างสำหรับหน้า Frontend', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => setState(() => slipAttached = true),
              icon: Icon(slipAttached ? Icons.check_circle_rounded : Icons.upload_file_rounded),
              label: Text(slipAttached ? 'แนบสลิปแล้ว (Demo)' : 'แนบสลิปการโอน'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => BookingDetailScreen(hotel: widget.hotel, total: widget.total)),
                (route) => route.isFirst,
              ),
              icon: const Icon(Icons.verified_rounded),
              label: const Text('ยืนยันการชำระเงิน'),
            ),
          ],
        ),
      ),
    );
  }
}
