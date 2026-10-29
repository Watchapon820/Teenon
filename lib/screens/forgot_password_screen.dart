import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';

/// ลืมรหัสผ่าน 2 ขั้น: 1) กรอกอีเมลเพื่อขอรหัสยืนยัน 6 หลัก  2) กรอกรหัสยืนยันและตั้งรหัสผ่านใหม่
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _emailOk = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (email.isEmpty) return _toast('กรอกอีเมล');
    await _run(() async {
      await ApiService.forgotPassword(email);
      if (!mounted) return;
      setState(() => _emailOk = true);
    });
  }

  Future<void> _reset() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) return _toast('กรอกรหัสยืนยัน 6 หลักจากอีเมล');
    if (_password.text.length < 6) return _toast('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร');
    if (_password.text != _confirm.text) return _toast('รหัสผ่านทั้งสองช่องไม่ตรงกัน');
    await _run(() async {
      await ApiService.resetPassword(email: _email.text.trim(), code: _code.text.trim(), password: _password.text);
      if (!mounted) return;
      _toast('ตั้งรหัสผ่านใหม่เรียบร้อยแล้ว กรุณาเข้าสู่ระบบ');
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลืมรหัสผ่าน')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _emailOk ? 'ตั้งรหัสผ่านใหม่' : 'กรอกอีเมลที่ใช้สมัคร',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _emailOk ? 'ถ้าอีเมลนี้มีอยู่ในระบบ เราได้ส่งรหัสยืนยัน 6 หลักไปแล้ว (ใช้ได้ 15 นาที) กรอกรหัสแล้วตั้งรหัสผ่านใหม่' : 'เราจะส่งรหัสยืนยัน 6 หลักไปที่อีเมลนี้',
                    style: const TextStyle(color: AppColors.textSoft),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _email,
                    enabled: !_emailOk,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'Email'),
                  ),
                  if (!_emailOk) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _loading ? null : _sendCode,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(_loading ? 'กำลังส่ง...' : 'ส่งรหัสยืนยัน'),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.pin_outlined), labelText: 'รหัสยืนยัน 6 หลัก', counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        labelText: 'รหัสผ่านใหม่',
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_reset_rounded), labelText: 'ยืนยันรหัสผ่านใหม่'),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _loading ? null : _reset,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(_loading ? 'กำลังบันทึก...' : 'ตั้งรหัสผ่านใหม่'),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _loading ? null : _sendCode,
                          child: const Text('ส่งรหัสอีกครั้ง'),
                        ),
                        TextButton(
                          onPressed: _loading ? null : () => setState(() => _emailOk = false),
                          child: const Text('เปลี่ยนอีเมล'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
