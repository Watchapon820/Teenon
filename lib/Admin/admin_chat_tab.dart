import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_thread.dart';
import 'admin_widgets.dart';

/// กล่องข้อความของแอดมิน: ลูกค้าที่เคยทักมา เรียงตามข้อความล่าสุด มีป้ายจำนวนที่ยังไม่ได้อ่าน
/// รีเฟรชเองทุก 5 วินาที กดเข้าไปตอบได้ที่ [AdminChatScreen]
class AdminChatTab extends StatefulWidget {
  const AdminChatTab({super.key, this.onChanged});

  /// เรียกหลังกลับจากห้องสนทนา (ให้หน้าแม่รีเฟรชป้ายแจ้งเตือนที่แท็บ)
  final VoidCallback? onChanged;

  @override
  State<AdminChatTab> createState() => _AdminChatTabState();
}

class _AdminChatTabState extends State<AdminChatTab> {
  List<Map<String, dynamic>>? _chats;
  Object? _error;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final list = await ApiService.adminChats();
      if (mounted) {
        setState(() {
          _chats = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _chats == null) setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  // 'YYYY-MM-DD HH:MM:SS' → เวลา ถ้าเป็นวันนี้ ไม่งั้นแสดงวัน/เดือน
  String _when(String ts) {
    if (ts.length < 16) return '';
    final n = DateTime.now();
    final today = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    return ts.startsWith(today) ? ts.substring(11, 16) : '${ts.substring(8, 10)}/${ts.substring(5, 7)}';
  }

  @override
  Widget build(BuildContext context) {
    final chats = _chats;
    if (chats == null) {
      if (_error == null) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorText(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }
    if (chats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('ยังไม่มีข้อความจากลูกค้า\nเมื่อลูกค้าทักเข้ามา จะแสดงที่นี่', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSoft)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: chats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = chats[i];
          final userId = (c['user_id'] as num).toInt();
          final name = ('${c['name'] ?? ''}'.trim().isNotEmpty ? '${c['name']}' : '${c['email'] ?? 'ลูกค้า #$userId'}').trim();
          final unread = (c['unread'] as num?)?.toInt() ?? 0;
          final preview = '${c['last_sender'] == 'admin' ? 'คุณ: ' : ''}${c['last_body'] ?? ''}';
          return Card(
            child: ListTile(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminChatScreen(userId: userId, name: name, email: '${c['email'] ?? ''}')),
                );
                _load();
                widget.onChanged?.call();
              },
              leading: CircleAvatar(
                backgroundColor: AppColors.adminBlue.withValues(alpha: 0.12),
                child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: const TextStyle(color: AppColors.adminBlue, fontWeight: FontWeight.w800)),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700)),
              subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? AppColors.text : AppColors.textSoft)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_when('${c['last_at']}'), style: const TextStyle(fontSize: 11, color: AppColors.textSoft)),
                  const SizedBox(height: 4),
                  if (unread > 0) Badge(label: Text(unread > 99 ? '99+' : '$unread'), backgroundColor: AppColors.danger) else const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ห้องสนทนากับลูกค้า 1 คน (ฝั่งแอดมิน)
class AdminChatScreen extends StatelessWidget {
  const AdminChatScreen({super.key, required this.userId, required this.name, this.email = ''});

  final int userId;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (email.isNotEmpty && email != name) Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textSoft, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: ChatThread(
        load: (after) => ApiService.adminChatMessages(userId, after: after),
        send: (body) => ApiService.adminChatSend(userId, body),
        emptyText: 'ยังไม่มีข้อความ',
      ),
    );
  }
}
