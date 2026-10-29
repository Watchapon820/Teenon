import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ห้องสนทนา 1 ห้อง (ใช้ทั้งฝั่งลูกค้าและแอดมิน): รายการข้อความ + ช่องพิมพ์
/// ดึงข้อความใหม่เองทุก [pollEvery] ด้วย load(after = id ข้อความล่าสุดที่มี)
class ChatThread extends StatefulWidget {
  const ChatThread({
    super.key,
    required this.load,
    required this.send,
    this.emptyText = 'ยังไม่มีข้อความ',
    this.pollEvery = const Duration(seconds: 3),
  });

  /// คืน { data: [{id, mine, body, created_at}], read_up_to: int }
  final Future<Map<String, dynamic>> Function(int after) load;
  final Future<void> Function(String body) send;
  final String emptyText;
  final Duration pollEvery;

  @override
  State<ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends State<ChatThread> {
  static const _maxLen = 1000;
  static const _months = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

  final List<Map<String, dynamic>> _msgs = [];
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _readUpTo = 0;
  bool _loaded = false;
  bool _polling = false;
  bool _pollAgain = false;
  bool _sending = false;
  bool _stickToBottom = false; // เลื่อนลงล่างสุดเมื่อข้อความชุดถัดไปมาถึง (เช่น หลังส่งข้อความ)
  Object? _error;

  int get _lastId => _msgs.isEmpty ? 0 : (_msgs.last['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(widget.pollEvery, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) {
      _pollAgain = true;
      return;
    }
    _polling = true;
    var more = false;
    try {
      final r = await widget.load(_lastId);
      if (!mounted) return;
      final fresh = (r['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      final readUp = (r['read_up_to'] as num?)?.toInt() ?? 0;
      more = fresh.length >= 200; // ยังมีข้อความค้างอีก ดึงต่อทันที
      if (fresh.isNotEmpty || readUp != _readUpTo || !_loaded || _error != null) {
        final nearBottom = !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 140;
        final first = !_loaded;
        setState(() {
          _msgs.addAll(fresh);
          _readUpTo = readUp;
          _loaded = true;
          _error = null;
        });
        if (first || _stickToBottom || (fresh.isNotEmpty && nearBottom)) _toBottom(animate: !first);
        if (fresh.isNotEmpty) _stickToBottom = false;
      }
    } catch (e) {
      if (mounted && !_loaded) setState(() => _error = e);
    } finally {
      _polling = false;
      if (mounted && (_pollAgain || more)) {
        _pollAgain = false;
        _poll();
      }
    }
  }

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(end, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.send(text);
      _input.clear();
      _stickToBottom = true;
      await _poll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _sending = false);
      _focus.requestFocus();
    }
  }

  // 'YYYY-MM-DD HH:MM:SS' → ส่วนวันที่/เวลา
  String _time(String ts) => ts.length >= 16 ? ts.substring(11, 16) : '';
  String _day(String ts) => ts.length >= 10 ? ts.substring(0, 10) : '';

  String _dayLabel(String day) {
    final now = DateTime.now();
    String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (day == ymd(now)) return 'วันนี้';
    if (day == ymd(now.subtract(const Duration(days: 1)))) return 'เมื่อวาน';
    final p = day.split('-');
    if (p.length != 3) return day;
    return '${int.tryParse(p[2]) ?? p[2]} ${_months[(int.tryParse(p[1]) ?? 1) - 1]} ${p[0]}';
  }

  Widget _dayChip(String day) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
            child: Text(_dayLabel(day), style: const TextStyle(fontSize: 11, color: AppColors.textSoft, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _bubble(Map<String, dynamic> m, double maxWidth) {
    final mine = m['mine'] == true;
    final read = mine && (m['id'] as num).toInt() <= _readUpTo;
    final fg = mine ? Colors.white : AppColors.text;
    final soft = mine ? Colors.white70 : AppColors.textSoft;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
        decoration: BoxDecoration(
          color: mine ? Theme.of(context).colorScheme.primary : Colors.white,
          border: mine ? null : Border.all(color: const Color(0xFFE3E8F2)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: Alignment.centerLeft, child: SelectableText('${m['body']}', style: TextStyle(color: fg, fontSize: 15, height: 1.35))),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_time('${m['created_at']}'), style: TextStyle(fontSize: 10.5, color: soft)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded, size: 14, color: read ? const Color(0xFF9FE8B8) : Colors.white54),
                  if (read) const Text(' อ่านแล้ว', style: TextStyle(fontSize: 10.5, color: Color(0xFF9FE8B8))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (!_loaded) {
      if (_error == null) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_error!}'.replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _poll, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }
    if (_msgs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined, size: 54, color: AppColors.textSoft),
              const SizedBox(height: 10),
              Text(widget.emptyText, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSoft)),
            ],
          ),
        ),
      );
    }
    final maxWidth = (MediaQuery.of(context).size.width * 0.78).clamp(220.0, 460.0);
    final rows = <Widget>[];
    String? lastDay;
    for (final m in _msgs) {
      final d = _day('${m['created_at']}');
      if (d != lastDay) {
        rows.add(_dayChip(d));
        lastDay = d;
      }
      rows.add(_bubble(m, maxWidth));
    }
    return ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(14, 6, 14, 10), children: rows);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _list()),
        Material(
          color: Colors.white,
          elevation: 6,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      maxLength: _maxLen,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'พิมพ์ข้อความ...', counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'ส่ง',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
