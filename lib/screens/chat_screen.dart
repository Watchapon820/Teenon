import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../auth/session.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/chat_thread.dart';
import 'contact_screen.dart';

/// แชทกับทีมงาน (แอดมิน) — ตอบโต้ได้ต่อเนื่อง ข้อความใหม่เข้ามาเองโดยไม่ต้องรีเฟรช
/// ช่องทางติดต่ออื่น (โทร/LINE/อีเมล) อยู่หลังปุ่ม ℹ︎ มุมขวาบน
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('แชทกับทีมงาน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('สอบถามการจอง การชำระเงิน หรือขอความช่วยเหลือ', style: TextStyle(fontSize: 11, color: AppColors.textSoft, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'ช่องทางติดต่ออื่น',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactScreen())),
          ),
        ],
      ),
      body: Session.isAdmin
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('ผู้ดูแลระบบตอบแชทลูกค้าได้ที่แท็บ "แชท" ในหน้าแอดมิน', textAlign: TextAlign.center)))
          : ChatThread(
              load: (after) => ApiService.chatMessages(after: after),
              send: ApiService.chatSend,
              emptyText: 'ทักทายทีมงานได้เลย\nเราจะตอบกลับโดยเร็วที่สุด',
            ),
    );
  }
}

/// ปุ่มแชทบนแถบหัวแอป พร้อมป้ายจำนวนข้อความจากทีมงานที่ยังไม่ได้อ่าน (เช็คเองทุก 15 วินาที)
class ChatButton extends StatefulWidget {
  const ChatButton({super.key});

  @override
  State<ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<ChatButton> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final n = await ApiService.chatUnread();
    if (mounted && n != _unread) setState(() => _unread = n);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: appBarIconStyle,
      tooltip: 'แชทกับทีมงาน',
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        _load();
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 9 ? '9+' : '$_unread'),
        child: const Icon(Icons.support_agent_rounded),
      ),
    );
  }
}
