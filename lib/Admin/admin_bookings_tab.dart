import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import 'admin_widgets.dart';

/// แท็บการจองของแอดมิน: ค้นหา + กรองตามสถานะ + ดูรายละเอียด/สลิป + ยืนยัน/ปฏิเสธ
class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({super.key, required this.filter, required this.onChanged});

  /// ตัวกรองสถานะ (ส่งมาจากแดชบอร์ดได้): all | pending_paid | pending_slip | confirmed | cancelled
  final ValueNotifier<String> filter;

  /// เรียกเมื่อมีการเปลี่ยนสถานะ (ให้แดชบอร์ดโหลดตัวเลขใหม่)
  final VoidCallback onChanged;

  @override
  State<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends State<AdminBookingsTab> {
  late Future<List<Map<String, dynamic>>> _future = ApiService.adminGetBookings();
  final _search = TextEditingController();

  static const _filters = {
    'all': 'ทั้งหมด',
    'pending_slip': 'รอตรวจสลิป',
    'pending_paid': 'รอชำระเงิน',
    'confirmed': 'ยืนยันแล้ว',
    'cancelled': 'ยกเลิก',
  };

  @override
  void initState() {
    super.initState();
    widget.filter.addListener(_onFilter);
  }

  @override
  void dispose() {
    widget.filter.removeListener(_onFilter);
    _search.dispose();
    super.dispose();
  }

  void _onFilter() {
    if (mounted) setState(() {});
  }

  void _reload() => setState(() => _future = ApiService.adminGetBookings());

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  String _statusKey(Map<String, dynamic> b) {
    final s = '${b['status']}';
    if (s == 'pending') return b['has_slip'] == true ? 'pending_slip' : 'pending_paid';
    return s;
  }

  String _statusText(Map<String, dynamic> b) {
    switch (_statusKey(b)) {
      case 'pending_slip':
        return 'รอตรวจสลิป';
      case 'pending_paid':
        return 'รอชำระเงิน';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      default:
        return 'ยืนยันแล้ว';
    }
  }

  Color _statusColor(Map<String, dynamic> b) {
    switch (_statusKey(b)) {
      case 'pending_slip':
        return AppColors.warning;
      case 'pending_paid':
        return AppColors.textSoft;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.success;
    }
  }

  bool _matches(Map<String, dynamic> b) {
    final f = widget.filter.value;
    if (f != 'all' && _statusKey(b) != f) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = '${b['booking_code']} ${b['hotel_name']} ${b['guest_name']} ${b['guest_email']} ${b['guest_phone']} ${b['user_name']} ${b['user_email']}'.toLowerCase();
    return hay.contains(q);
  }

  Future<void> _confirm(Map<String, dynamic> b) async {
    if (b['has_slip'] != true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ยังไม่มีสลิป'),
          content: const Text('ลูกค้ายังไม่ได้ส่งสลิปการโอนเงิน ต้องการยืนยันการจองนี้หรือไม่?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยันเลย')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await ApiService.adminConfirmBooking('${b['booking_code']}');
      _toast('ยืนยันการจองแล้ว (แจ้งลูกค้าแล้ว)');
      widget.onChanged();
      _reload();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _reject(Map<String, dynamic> b) async {
    const presets = ['ห้องเต็ม', 'สลิปไม่ถูกต้อง / ยอดไม่ตรง', 'ลูกค้าขอยกเลิก', 'ไม่ได้ชำระเงินตามกำหนด'];
    var reason = presets.first;
    final custom = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(b['status'] == 'pending' ? 'ปฏิเสธการจอง' : 'ยกเลิกการจอง'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b['booking_code']} · ${b['hotel_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final p in presets)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(p),
                    value: p,
                    groupValue: reason,
                    onChanged: (v) => setD(() => reason = v ?? reason),
                  ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('อื่นๆ'),
                  value: 'custom',
                  groupValue: reason,
                  onChanged: (v) => setD(() => reason = v ?? reason),
                ),
                if (reason == 'custom') TextField(controller: custom, decoration: const InputDecoration(labelText: 'ระบุเหตุผล')),
                const SizedBox(height: 6),
                const Text('ลูกค้าจะได้รับการแจ้งเตือนพร้อมเหตุผลนี้', style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ปิด')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยันยกเลิก'),
            ),
          ],
        ),
      ),
    );
    final text = reason == 'custom' ? custom.text.trim() : reason;
    custom.dispose();
    if (ok != true) return;
    if (text.isEmpty) return _toast('ระบุเหตุผล');
    try {
      await ApiService.adminCancelBooking('${b['booking_code']}', reason: text);
      _toast('ยกเลิกการจองแล้ว (แจ้งลูกค้าแล้ว)');
      widget.onChanged();
      _reload();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _viewSlip(String code) async {
    try {
      final Uint8List bytes = await ApiService.getSlip(code);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ปิด')),
            ],
          ),
        ),
      );
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _detail(Map<String, dynamic> b) async {
    String v(String key, [String empty = '-']) {
      final x = b[key]?.toString().trim() ?? '';
      return x.isEmpty ? empty : x;
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.black54))),
              Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );

    final status = '${b['status']}';
    final method = b['payment_method'] == 'promptpay' ? 'PromptPay QR' : (b['payment_method'] == 'bank' ? 'โอนเข้าบัญชี' : '-');

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(v('booking_code'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                  Text(_statusText(b), style: TextStyle(color: _statusColor(b), fontWeight: FontWeight.w800)),
                ],
              ),
              const Divider(height: 24),
              row('โรงแรม', v('hotel_name')),
              row('ที่ตั้ง', v('hotel_location')),
              row('ห้องพัก', v('room_label')),
              row('เช็คอิน', v('check_in_date')),
              row('เช็คเอาต์', v('check_out_date')),
              row('จำนวนห้อง', v('num_rooms')),
              row('จำนวนผู้เข้าพัก', v('num_guests')),
              row('ยอดรวม', '${v('total_amount')} ฿'),
              const Divider(height: 24),
              row('ผู้จอง (บัญชี)', '${v('user_name')} (${v('user_email')})'),
              row('ชื่อผู้เข้าพัก', v('guest_name')),
              row('อีเมลผู้เข้าพัก', v('guest_email')),
              row('เบอร์โทร', v('guest_phone')),
              row('คำขอพิเศษ', v('special_request')),
              const Divider(height: 24),
              row('ช่องทางชำระ', method),
              row('ส่งสลิปเมื่อ', v('paid_at')),
              if (b['has_slip'] == true)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton.icon(
                    onPressed: () => _viewSlip('${b['booking_code']}'),
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('ดูสลิปการโอน'),
                  ),
                ),
              if (status == 'cancelled') ...[
                const Divider(height: 24),
                row('เหตุผลที่ยกเลิก', v('cancel_reason')),
                row('รายละเอียดเพิ่มเติม', v('cancel_details')),
                row('ยกเลิกเมื่อ', v('cancelled_at')),
              ],
              if (status != 'cancelled') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(ctx, 'reject'),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(status == 'pending' ? 'ปฏิเสธ' : 'ยกเลิกการจอง'),
                      ),
                    ),
                    if (status == 'pending') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'confirm'),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('ยืนยันการจอง'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (action == 'confirm') await _confirm(b);
    if (action == 'reject') await _reject(b);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ค้นหา รหัสจอง / ชื่อ / อีเมล / โรงแรม',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_search.clear)),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final e in _filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: widget.filter.value == e.key,
                    onSelected: (_) => widget.filter.value = e.key,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(errorText(snap.error!)),
                      const SizedBox(height: 10),
                      FilledButton(onPressed: _reload, child: const Text('ลองใหม่')),
                    ],
                  ),
                );
              }
              final list = snap.data!.where(_matches).toList();
              if (list.isEmpty) return const Center(child: Text('ไม่พบรายการจอง'));
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = list[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _detail(b),
                        title: Text('${b['booking_code']} · ${b['hotel_name'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${b['user_name'] ?? b['guest_name'] ?? '-'} (${b['user_email'] ?? b['guest_email'] ?? '-'})\n'
                          '${b['check_in_date']} → ${b['check_out_date']} · ${b['total_amount']}฿',
                        ),
                        isThreeLine: true,
                        trailing: _statusKey(b) == 'pending_slip'
                            ? FilledButton(onPressed: () => _confirm(b), child: const Text('ยืนยัน'))
                            : Text(_statusText(b), style: TextStyle(color: _statusColor(b), fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
