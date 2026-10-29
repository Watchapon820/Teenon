import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// หน้า "ช่องทางติดต่ออื่น ๆ": แสดงช่องทางติดต่อจริงที่ตั้งไว้ในเซิร์ฟเวอร์ (.env: CONTACT_PHONE / CONTACT_LINE / CONTACT_EMAIL / CONTACT_HOURS)
/// เปิดจากปุ่ม ℹ︎ ในหน้าแชท หรือปุ่ม "โทรหาเรา" ในหน้าแรก
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  late Future<Map<String, dynamic>> _future = ApiService.getContact();

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('คัดลอก$labelแล้ว')));
  }

  Widget _tile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(value),
      trailing: const Icon(Icons.copy_rounded, size: 18),
      onTap: () => _copy(label, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ติดต่อเรา')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snap.error}'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => setState(() => _future = ApiService.getContact()), child: const Text('ลองใหม่')),
                    ],
                  ),
                ),
              );
            }
            final c = snap.data ?? {};
            String v(String k) => (c[k] ?? '').toString().trim();
            final hasAny = v('phone').isNotEmpty || v('line').isNotEmpty || v('email').isNotEmpty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              children: [
                const AppSectionTitle(title: 'ติดต่อทีมงาน', subtitle: 'สอบถามการจอง การชำระเงิน หรือขอความช่วยเหลือ'),
                const SizedBox(height: 14),
                Card(
                  child: hasAny
                      ? Column(
                          children: [
                            if (v('phone').isNotEmpty) _tile(Icons.phone_rounded, 'โทรศัพท์', v('phone')),
                            if (v('line').isNotEmpty) _tile(Icons.chat_rounded, 'LINE', v('line')),
                            if (v('email').isNotEmpty) _tile(Icons.mail_rounded, 'อีเมล', v('email')),
                          ],
                        )
                      : const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('เบอร์ติดต่อ 0891494909 ', style: TextStyle(color: AppColors.textSoft)),
                        ),
                ),
                if (v('hours').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(child: _tile(Icons.schedule_rounded, 'เวลาทำการ', v('hours'))),
                ],
                const SizedBox(height: 12),
                const Text('แตะที่ช่องทางเพื่อคัดลอก', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
              ],
            );
          },
        ),
      ),
    );
  }
}
