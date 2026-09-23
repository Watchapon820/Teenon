import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.teal]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  children: [
                    GradientIconBox(icon: Icons.card_travel_rounded, size: 62, colors: [Colors.white24, Colors.white10]),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('เริ่มต้นทริปกับ Teenon', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                          SizedBox(height: 5),
                          Text('สมัครสมาชิกเพื่อบันทึกโรงแรมและจัดการการจองได้สะดวกขึ้น', style: TextStyle(color: Color(0xFFE7F6FF), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), labelText: 'ชื่อผู้ใช้งาน')),
                      const SizedBox(height: 12),
                      const TextField(keyboardType: TextInputType.emailAddress, decoration: InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'Email')),
                      const SizedBox(height: 12),
                      const TextField(obscureText: true, decoration: InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded), labelText: 'Password')),
                      const SizedBox(height: 12),
                      const TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(prefixIcon: Icon(Icons.phone_outlined), labelText: 'เบอร์โทร')),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('สมัครสมาชิก'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
