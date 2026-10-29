import 'package:flutter/material.dart';

import '../auth/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.coralLight]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  const GradientIconBox(icon: Icons.tune_rounded, size: 64, colors: [Colors.white24, Colors.white10]),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ตั้งค่าแอป', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(Session.email, style: const TextStyle(color: Color(0xFFEAF1FF), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                    title: const Text('การแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('สถานะการจองและการชำระเงิน'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                    title: const Text('ติดต่อเรา / ช่วยเหลือ', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('แชทกับทีมงาน'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: AppColors.primary),
                    title: Text('เกี่ยวกับ Teenon', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('แอปจองโรงแรม เวอร์ชัน 1.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Session.clear();
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('ออกจากระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}
