import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

class TeenonApp extends StatelessWidget {
  const TeenonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Teenon Hotel Booking',
      theme: buildAppTheme(),
      home: const LoginScreen(),
    );
  }
}
