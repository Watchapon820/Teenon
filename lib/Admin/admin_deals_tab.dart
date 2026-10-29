import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import 'admin_widgets.dart';

/// จัดการดีล/โปรโมชัน: ส่วนลด % ของโรงแรมในช่วงวันที่ที่กำหนด (ใช้กับทุกประเภทห้องของโรงแรมนั้น)
/// ลูกค้าเห็นป้าย "ลด X%" และราคาหลังลดในแอป และยอดตอนจองหักส่วนลดให้อัตโนมัติ (คิดที่ server)
/// ดีลมีผลเมื่อ: เปิดอยู่ และวันที่ลูกค้ากดจองอยู่ในช่วงเริ่ม–สิ้นสุด (รวมวันสุดท้าย) · ถ้าซ้อนกันใช้ส่วนลดสูงสุด
class AdminDealsTab extends StatefulWidget {
  const AdminDealsTab({super.key});

  @override
  State<AdminDealsTab> createState() => _AdminDealsTabState();
}

class _AdminDealsTabState extends State<AdminDealsTab> {
  List<Map<String, dynamic>>? _deals;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ApiService.adminGetDeals();
      if (mounted) {
        setState(() {
          _deals = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _deals == null) setState(() => _error = e);
    }
  }

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parse(dynamic v) {
    final s = '${v ?? ''}';
    return s.length >= 10 ? DateTime.tryParse(s.substring(0, 10)) : null;
  }

  String _show(dynamic v) {
    final s = '${v ?? ''}';
    return s.length >= 10 ? '${s.substring(8, 10)}/${s.substring(5, 7)}/${s.substring(0, 4)}' : '-';
  }

  (String, Color) _status(Map<String, dynamic> d) {
    switch ('${d['status']}') {
      case 'active':
        return ('กำลังใช้งาน', AppColors.success);
      case 'scheduled':
        return ('ยังไม่เริ่ม', AppColors.adminBlue);
      case 'expired':
        return ('หมดอายุ', AppColors.textSoft);
      default:
        return ('ปิดอยู่', AppColors.warning);
    }
  }

  Future<void> _toggle(Map<String, dynamic> d, bool on) async {
    try {
      await ApiService.adminSaveDeal(id: (d['deal_id'] as num).toInt(), fields: {'isActive': on});
      await _load();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบดีล'),
        content: Text('ลบดีล "${d['title']}" ของ ${d['hotel_name']} ?\nการจองที่เคยใช้ดีลนี้ยังคงได้ราคาที่ลดแล้วตามเดิม'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.adminDeleteDeal((d['deal_id'] as num).toInt());
      await _load();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  // ฟอร์มสร้าง/แก้ไขดีล
  Future<void> _form([Map<String, dynamic>? deal]) async {
    List<Map<String, dynamic>> hotels = [];
    try {
      hotels = await ApiService.getHotels();
    } catch (_) {}
    if (!mounted) return;
    if (hotels.isEmpty) return _toast('ยังไม่มีโรงแรมให้ตั้งดีล เพิ่มโรงแรมก่อน');

    final titleC = TextEditingController(text: '${deal?['title'] ?? ''}');
    final descC = TextEditingController(text: '${deal?['description'] ?? ''}');
    final pctC = TextEditingController(text: deal == null ? '10' : '${deal['discount_percent']}');
    int? hotelId = deal == null ? int.tryParse('${hotels.first['hotel_id']}') : (deal['hotel_id'] as num).toInt();
    final today = DateTime.now();
    DateTime start = _parse(deal?['start_date']) ?? DateTime(today.year, today.month, today.day);
    DateTime end = _parse(deal?['end_date']) ?? start.add(const Duration(days: 30));
    bool active = deal == null ? true : deal['is_active'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Future<void> pick(bool isStart) async {
            final init = isStart ? start : end;
            final d = await showDatePicker(
              context: ctx,
              initialDate: init,
              firstDate: DateTime(today.year - 1),
              lastDate: DateTime(today.year + 3),
            );
            if (d == null) return;
            setD(() {
              if (isStart) {
                start = d;
                if (end.isBefore(start)) end = start;
              } else {
                end = d;
              }
            });
          }

          return AlertDialog(
            title: Text(deal == null ? 'เพิ่มดีล' : 'แก้ไขดีล'),
            // กำหนดความกว้างตายตัว: เนื้อหาใน AlertDialog ที่มีช่องกว้างเต็มต้องมีขนาดแน่นอน
            content: SizedBox(
              width: 340,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: hotelId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'โรงแรม'),
                      items: [
                        for (final h in hotels) DropdownMenuItem(value: int.tryParse('${h['hotel_id']}'), child: Text('${h['name']}', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setD(() => hotelId = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: titleC, maxLength: 100, decoration: const InputDecoration(labelText: 'ชื่อดีล', hintText: 'เช่น ลดต้อนรับหน้าฝน', counterText: '')),
                    const SizedBox(height: 10),
                    TextField(controller: descC, maxLength: 255, decoration: const InputDecoration(labelText: 'คำอธิบาย (ไม่บังคับ)', counterText: '')),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pctC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ส่วนลด (%)', helperText: 'จำนวนเต็ม 1-90 ใช้กับทุกประเภทห้องของโรงแรม', suffixText: '%'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => pick(true), icon: const Icon(Icons.event_rounded, size: 18), label: Text('เริ่ม ${_show(_ymd(start))}', style: const TextStyle(fontSize: 13)))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton.icon(onPressed: () => pick(false), icon: const Icon(Icons.event_available_rounded, size: 18), label: Text('ถึง ${_show(_ymd(end))}', style: const TextStyle(fontSize: 13)))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('เปิดใช้งานดีลนี้'), value: active, onChanged: (v) => setD(() => active = v)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
            ],
          );
        },
      ),
    );
    final title = titleC.text.trim();
    final desc = descC.text.trim();
    final pct = int.tryParse(pctC.text.trim());
    titleC.dispose();
    descC.dispose();
    pctC.dispose();
    if (ok != true) return;
    if (hotelId == null) return _toast('เลือกโรงแรม');
    if (title.isEmpty) return _toast('ตั้งชื่อดีล');
    if (pct == null || pct < 1 || pct > 90) return _toast('ส่วนลดต้องเป็นจำนวนเต็ม 1-90 %');
    try {
      await ApiService.adminSaveDeal(
        id: deal == null ? null : (deal['deal_id'] as num).toInt(),
        fields: {
          'hotelId': hotelId,
          'title': title,
          'description': desc,
          'discountPercent': pct,
          'startDate': _ymd(start),
          'endDate': _ymd(end),
          'isActive': active,
        },
      );
      _toast(deal == null ? 'เพิ่มดีลแล้ว' : 'บันทึกดีลแล้ว');
      await _load();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deals = _deals;
    if (deals == null) {
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
    final activeCount = deals.where((d) => d['status'] == 'active').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('ใช้งานอยู่ $activeCount จาก ${deals.length} ดีล', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              FilledButton.icon(onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: const Text('เพิ่มดีล')),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'ดีลที่กำลังใช้งานจะแสดงในหมวด "ดีล" ของแอป พร้อมป้ายส่วนลดและราคาหลังลด',
            style: TextStyle(color: AppColors.textSoft, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (deals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('ยังไม่มีดีล กด "เพิ่มดีล" เพื่อสร้างโปรโมชันแรก', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSoft))),
            ),
          for (final d in deals) ...[
            _card(d),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> d) {
    final (label, color) = _status(d);
    final on = d['is_active'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Text('-${d['discount_percent']}%', textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${d['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${d['hotel_name'] ?? '-'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${_show(d['start_date'])} – ${_show(d['end_date'])}', style: const TextStyle(color: AppColors.textSoft, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: on, onChanged: (v) => _toggle(d, v)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(tooltip: 'แก้ไขดีล', visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _form(d)),
                    IconButton(tooltip: 'ลบดีล', visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger), onPressed: () => _delete(d)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
