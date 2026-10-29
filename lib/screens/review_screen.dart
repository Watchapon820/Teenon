import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.hotelName, required this.bookingCode});

  final String hotelName;
  final String bookingCode;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int rating = 5;
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ApiService.submitReview(bookingCode: widget.bookingCode, rating: rating, comment: _comment.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ขอบคุณสำหรับรีวิว')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เขียนรีวิว')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            AppSectionTitle(title: 'รีวิวที่พัก', subtitle: widget.hotelName),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const GradientIconBox(icon: Icons.rate_review_rounded, size: 68),
                    const SizedBox(height: 16),
                    const Text('ประสบการณ์โดยรวมเป็นอย่างไร?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          onPressed: () => setState(() => rating = value),
                          icon: Icon(value <= rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF5A623), size: 34),
                        );
                      }),
                    ),
                    Text('$rating / 5', style: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _comment,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: const InputDecoration(labelText: 'เขียนรีวิว', alignLabelWithHint: true, hintText: 'เช่น ห้องสะอาด บริการดี...'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: Text(_sending ? 'กำลังส่ง...' : 'ส่งรีวิว'),
            ),
          ],
        ),
      ),
    );
  }
}
