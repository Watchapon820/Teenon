import 'package:flutter/material.dart';

import '../Admin/admin_rooms_screen.dart';
import '../Admin/room_repository.dart';
import '../api_service.dart';
import '../auth/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _toast('กรอกอีเมลและรหัสผ่าน');
      return;
    }
    setState(() => loading = true);
    try {
      await ApiService.login(email, password);
      if (!mounted) return;
      // แยกหน้าตาม role: admin → หน้าแอดมิน, user → หน้าหลัก
      final Widget next = Session.isAdmin
          ? AdminRoomsScreen(repository: ApiRoomRepository())
          : const HomeScreen();
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => next), (route) => false);
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ส่วนหัว: ภาพตึก (assets/images/login_bg.png) เป็นพื้นหลัง + แถบสีครีมจางทางซ้ายให้ข้อความอ่านง่าย
              Container(
                height: 245,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F3EC),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/login_bg.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [const Color(0xFFF6F3EC).withValues(alpha: 0.95), const Color(0xFFF6F3EC).withValues(alpha: 0.0)],
                            stops: const [0.35, 0.85],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              AppLogo(size: 54),
                              SizedBox(width: 12),
                              Text('Teenon', style: TextStyle(color: AppColors.navy, fontSize: 31, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const Spacer(),
                          const Text('ค้นหาที่พักที่ใช่สำหรับคุณ', style: TextStyle(color: AppColors.navy, fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text('ค้นหา เปรียบเทียบ และจองโรงแรมได้ง่ายในแอปเดียว', style: TextStyle(color: AppColors.textSoft, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -18),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('ยินดีต้อนรับกลับมา', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
                        const SizedBox(height: 4),
                        const Text('เข้าสู่ระบบเพื่อดูดีลและจัดการการจองของคุณ', style: TextStyle(color: AppColors.textSoft)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'อีเมล'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            labelText: 'รหัสผ่าน',
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => obscure = !obscure),
                              icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ForgotPasswordScreen(initialEmail: emailController.text.trim())),
                            ),
                            child: const Text('ลืมรหัสผ่าน?'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FilledButton.icon(onPressed: loading ? null : login, icon: const Icon(Icons.login_rounded), label: Text(loading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ')),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('สร้างบัญชีใหม่'),
                        ),
                      ],
                    ),
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
