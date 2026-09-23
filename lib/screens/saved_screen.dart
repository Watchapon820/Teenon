import 'package:flutter/material.dart';

import '../data/dummy_data.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';
import 'hotel_detail_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final savedHotels = [hotels[0], hotels[2], hotels[3]];
    return AppShell(
      currentIndex: 2,
      title: 'Your favorite stays',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const AppSectionTitle(title: 'Saved stays', subtitle: 'โรงแรมที่คุณบันทึกไว้ดูภายหลัง'),
          const SizedBox(height: 14),
          for (final hotel in savedHotels) ...[
            HotelCard(
              hotel: hotel,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelDetailScreen(hotel: hotel))),
              compact: true,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
