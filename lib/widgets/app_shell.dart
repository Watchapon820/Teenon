import 'package:flutter/material.dart';

import '../screens/booking_list_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/hotel_list_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';

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
        toolbarHeight: 78,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Teenon', style: TextStyle(color: AppColors.navy, fontSize: 25, fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(color: AppColors.textSoft, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          ...?actions,
          IconButton(
            tooltip: 'Chat',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
            icon: const Icon(Icons.support_agent_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(top: false, child: child),
      bottomNavigationBar: showNavigation
          ? NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                if (index != currentIndex) go(context, index);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.hotel_rounded), label: 'Hotels'),
                NavigationDestination(icon: Icon(Icons.favorite_rounded), label: 'Saved'),
                NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Bookings'),
                NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            )
          : null,
    );
  }
}
