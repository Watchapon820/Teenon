import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// ไอคอนกระดิ่งพร้อมจุดแจ้งจำนวนที่ยังไม่ได้อ่าน (วางใน AppBar)
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getNotifications();
      if (mounted) setState(() => _unread = (data['unread'] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      style: appBarIconStyle,
      tooltip: 'การแจ้งเตือน',
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        _load();
      },
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 9 ? '9+' : '$_unread'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final data = await ApiService.getNotifications();
    // เปิดหน้านี้ = อ่านแล้ว (ยังแสดงจุดสีของรายการใหม่ในรอบนี้)
    if (((data['unread'] as num?) ?? 0) > 0) ApiService.markNotificationsRead();
    return data;
  }

  String _when(dynamic v) {
    final s = v?.toString() ?? '';
    return s.length >= 16 ? s.substring(0, 16).replaceFirst('T', ' ') : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
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
                      FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('ลองใหม่')),
                    ],
                  ),
                ),
              );
            }
            final list = (snap.data!['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
            if (list.isEmpty) return const Center(child: Text('ยังไม่มีการแจ้งเตือน', style: TextStyle(color: AppColors.textSoft)));
            return RefreshIndicator(
              onRefresh: () async => setState(() => _future = _load()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = list[i];
                  final unread = n['is_read'] == 0 || n['is_read'] == false;
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.notifications_rounded, color: unread ? AppColors.primary : AppColors.textSoft),
                      title: Text('${n['title']}', style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700)),
                      subtitle: Text('${n['body']}\n${_when(n['created_at'])}'),
                      isThreeLine: true,
                      trailing: unread ? const Icon(Icons.circle, size: 10, color: AppColors.primary) : null,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
