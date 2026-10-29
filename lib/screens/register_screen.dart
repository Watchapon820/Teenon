import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    setState(() => loading = true);
    try {
      await ApiService.register(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        phone: phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างบัญชีใหม่')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.coralLight]),
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
                          Text('เริ่มต้นทริปกับ Teenon', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
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
                      TextField(controller: nameController, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), labelText: 'ชื่อผู้ใช้งาน')),
                      const SizedBox(height: 12),
                      TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'อีเมล')),
                      const SizedBox(height: 12),
                      TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline_rounded), labelText: 'รหัสผ่าน')),
                      const SizedBox(height: 12),
                      TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined), labelText: 'เบอร์โทร')),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: loading ? null : register,
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: Text(loading ? 'กำลังสมัคร...' : 'สมัครสมาชิก'),
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