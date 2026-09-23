import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(text: 'demo@teenon.app');
  final passwordController = TextEditingController(text: '123456');
  bool obscure = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 245,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.primary, AppColors.teal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  children: [
                    const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.apartment_rounded, size: 108, color: Colors.white12),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            GradientIconBox(icon: Icons.hotel_class_rounded, size: 50, colors: [Colors.white24, Colors.white10]),
                            SizedBox(width: 12),
                            Text('Teenon', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const Spacer(),
                        const Text('Find your perfect stay', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                          'ค้นหา เปรียบเทียบ และจองโรงแรมได้ง่ายในแอปเดียว',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                        ),
                      ],
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
                        const Text('Welcome back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text)),
                        const SizedBox(height: 4),
                        const Text('เข้าสู่ระบบเพื่อดูดีลและจัดการการจองของคุณ', style: TextStyle(color: AppColors.textSoft)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => obscure = !obscure),
                              icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(onPressed: login, icon: const Icon(Icons.login_rounded), label: const Text('เข้าสู่ระบบ')),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('สร้างบัญชีใหม่'),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Frontend Demo • ยังไม่เชื่อม Backend / Database',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSoft, fontSize: 12),
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
