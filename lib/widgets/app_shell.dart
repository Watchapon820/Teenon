import 'package:flutter/material.dart';

import '../screens/booking_list_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/hotel_list_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.child,
    this.showNavigation = true,
    this.actions,
  });

  final int currentIndex;
  final String title;
  final Widget child;
  final bool showNavigation;
  final List<Widget>? actions;

  static void go(BuildContext context, int index) {
    final Widget page = switch (index) {
      0 => const HomeScreen(),
      1 => const HotelListScreen(),
      2 => const SavedScreen(),
      3 => const BookingListScreen(),
      _ => const ProfileScreen(),
    };
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        titleSpacing: 20,
        title: Row(
          children: [
            const AppLogo(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Teenon', style: TextStyle(color: AppColors.navy, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSoft, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ...?actions,
          // ปุ่มไอคอนด้านขวาเป็นวงกลมสีขาว ไอคอนสีส้ม
          Theme(
            data: Theme.of(context).copyWith(
              iconButtonTheme: IconButtonThemeData(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  fixedSize: const Size(42, 42),
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NotificationBell(),
                const SizedBox(width: 6),
                const ChatButton(),
                const SizedBox(width: 6),
                IconButton(
                  style: appBarIconStyle,
                  tooltip: 'ตั้งค่า',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(top: false, child: child),
      bottomNavigationBar: showNavigation
          ? PillNavBar(
              color: AppColors.primary,
              currentIndex: currentIndex,
              items: const [
                NavItem(Icons.home_rounded, 'หน้าแรก'),
                NavItem(Icons.hotel_rounded, 'โรงแรม'),
                NavItem(Icons.favorite_rounded, 'บันทึกไว้'),
                NavItem(Icons.receipt_long_rounded, 'การจอง'),
                NavItem(Icons.person_rounded, 'โปรไฟล์'),
              ],
              onTap: (index) {
                if (index != currentIndex) go(context, index);
              },
            )
          : null,
    );
  }
}
