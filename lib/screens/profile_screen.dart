import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController(text: 'Teenon Member');
  final email = TextEditingController(text: 'demo@teenon.app');
  final phone = TextEditingController(text: '08X-XXX-XXXX');
  final contact = TextEditingController(text: 'LINE: @teenon');
  bool editing = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: 4,
      title: 'Your account',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.teal]),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 37,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.text, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(email.text, style: const TextStyle(color: Color(0xFFE8F6FF), fontSize: 13)),
                      const SizedBox(height: 8),
                      const AppChip(label: 'Teenon Member', icon: Icons.verified_rounded, accent: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('ข้อมูลส่วนตัว', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.text)),
                  const SizedBox(height: 14),
                  TextField(controller: name, enabled: editing, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), labelText: 'ชื่อ')),
                  const SizedBox(height: 12),
                  TextField(controller: email, enabled: editing, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'อีเมล')),
                  const SizedBox(height: 12),
                  TextField(controller: phone, enabled: editing, keyboardType: TextInputType.phone, decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined), labelText: 'เบอร์โทร')),
                  const SizedBox(height: 12),
                  TextField(controller: contact, enabled: editing, decoration: const InputDecoration(prefixIcon: Icon(Icons.alternate_email_rounded), labelText: 'ช่องทางติดต่ออื่น ๆ')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => editing = !editing),
                          icon: Icon(editing ? Icons.close_rounded : Icons.edit_rounded),
                          label: Text(editing ? 'ยกเลิก' : 'แก้ไข'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: editing
                              ? () {
                                  setState(() => editing = false);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลบนหน้าจอแล้ว (Frontend Demo)')));
                                }
                              : null,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('บันทึก'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
