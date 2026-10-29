import 'package:flutter/material.dart';

import 'auth/session.dart';
import 'screens/startup_screen.dart';
import 'theme/app_theme.dart';

class TeenonApp extends StatelessWidget {
  const TeenonApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ผู้ใช้ทั่วไปได้ธีมส้ม แอดมินได้ธีมฟ้า (สลับอัตโนมัติเมื่อล็อกอิน/ออกจากระบบ)
    return ValueListenableBuilder<bool>(
      valueListenable: Session.adminMode,
      builder: (context, admin, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Teenon Hotel Booking',
        theme: buildAppTheme(admin: admin),
        home: const StartupScreen(),
      ),
    );
  }
}
