import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.hotelName});

  final String hotelName;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int rating = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a review')),
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
                    const Text('ประสบการณ์โดยรวมเป็นอย่างไร?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
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
                    const TextField(maxLines: 5, decoration: InputDecoration(labelText: 'เขียนรีวิว', alignLabelWithHint: true, hintText: 'เช่น ห้องสะอาด บริการดี...')),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('แนบรูปภาพ (Demo)')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกรีวิวบนหน้าจอแล้ว (Frontend Demo)')));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('ส่งรีวิว'),
            ),
          ],
        ),
      ),
    );
  }
}
