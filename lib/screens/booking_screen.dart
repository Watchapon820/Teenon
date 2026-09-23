import 'package:flutter/material.dart';

import '../models/hotel.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'payment_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.hotel});

  final Hotel hotel;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String room = 'Deluxe Room';
  int rooms = 1;
  int guests = 2;

  @override
  Widget build(BuildContext context) {
    final total = widget.hotel.price * 2 * rooms;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            AppSectionTitle(title: 'Booking details', subtitle: widget.hotel.name),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    InfoRow(icon: Icons.hotel_rounded, label: 'โรงแรม', value: widget.hotel.name),
                    const InfoRow(icon: Icons.calendar_month_rounded, label: 'Check-in', value: '20 Aug 2026'),
                    const InfoRow(icon: Icons.event_rounded, label: 'Check-out', value: '22 Aug 2026'),
                    const InfoRow(icon: Icons.nights_stay_rounded, label: 'จำนวนคืน', value: '2 คืน'),
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
                    const Text('ข้อมูลผู้จอง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const SizedBox(height: 14),
                    const TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), labelText: 'ชื่อผู้จอง')),
                    const SizedBox(height: 12),
                    const TextField(keyboardType: TextInputType.emailAddress, decoration: InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'Email')),
                    const SizedBox(height: 12),
                    const TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(prefixIcon: Icon(Icons.phone_outlined), labelText: 'เบอร์โทร')),
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
                    const Text('รายละเอียดห้อง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: room,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.bed_rounded), labelText: 'ประเภทห้อง'),
                      items: const ['Deluxe Room', 'Double Room', 'Master Room'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (value) => setState(() => room = value ?? room),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _StepperField(label: 'จำนวนห้อง', value: rooms, onMinus: () => setState(() => rooms = rooms > 1 ? rooms - 1 : 1), onPlus: () => setState(() => rooms++))),
                        const SizedBox(width: 10),
                        Expanded(child: _StepperField(label: 'ผู้เข้าพัก', value: guests, onMinus: () => setState(() => guests = guests > 1 ? guests - 1 : 1), onPlus: () => setState(() => guests++))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TextField(maxLines: 3, decoration: InputDecoration(prefixIcon: Icon(Icons.notes_rounded), labelText: 'คำขอเพิ่มเติม', alignLabelWithHint: true)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const GradientIconBox(icon: Icons.payments_rounded),
                    const SizedBox(width: 14),
                    const Expanded(child: Text('ยอดรวมโดยประมาณ\n2 คืน', style: TextStyle(color: AppColors.textSoft))),
                    Text('$total฿', style: const TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(hotel: widget.hotel, total: total))),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('ไปหน้าชำระเงิน'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({required this.label, required this.value, required this.onMinus, required this.onPlus});

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(onPressed: onMinus, visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_rounded, size: 18)),
              Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              IconButton.filledTonal(onPressed: onPlus, visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_rounded, size: 18)),
            ],
          ),
        ],
      ),
    );
  }
}
