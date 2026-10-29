import 'package:flutter/material.dart';

import '../Admin/admin_rooms_screen.dart';
import '../Admin/room_repository.dart';
import '../api_service.dart';
import '../auth/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// หน้าแรกตอนเปิดแอป: ถ้ามี token ที่จำไว้และยังใช้ได้ ไปหน้าหลัก/แอดมินเลย ไม่ต้องล็อกอินซ้ำ
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Session.restore();
    final ok = await ApiService.loadMe();
    if (!mounted) return;
    final Widget next = !ok
        ? const LoginScreen()
        : (Session.isAdmin ? AdminRoomsScreen(repository: ApiRoomRepository()) : const HomeScreen());
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 72),
            SizedBox(height: 12),
            Text('Teenon', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.navy)),
            SizedBox(height: 20),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}
