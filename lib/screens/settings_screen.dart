import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true;
  bool promotions = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.navy, AppColors.primary]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                children: [
                  GradientIconBox(icon: Icons.tune_rounded, size: 64, colors: [Colors.white24, Colors.white10]),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ตั้งค่าแอป', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('ปรับการแจ้งเตือนและตัวเลือกการใช้งาน', style: TextStyle(color: Color(0xFFEAF1FF), fontSize: 13)),
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
                  SwitchListTile(
                    value: notifications,
                    onChanged: (value) => setState(() => notifications = value),
                    secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                    title: const Text('การแจ้งเตือน', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('แจ้งเตือนสถานะการจองและการชำระเงิน'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: promotions,
                    onChanged: (value) => setState(() => promotions = value),
                    secondary: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
                    title: const Text('โปรโมชั่น', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('รับข่าวสารและดีลที่น่าสนใจ'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                    title: const Text('ช่วยเหลือ', style: TextStyle(fontWeight: FontWeight.w800)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ศูนย์ช่วยเหลือ (Frontend Demo)'))),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined, color: AppColors.primary),
                    title: const Text('รูปลักษณ์', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Light theme'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: AppColors.primary),
                    title: Text('เกี่ยวกับ Teenon', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Flutter Frontend Demo v1.0'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('ออกจากระบบ'),
            ),
          ],
        ),
      ),
    );
  }
}
