import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../theme/app_theme.dart';
import 'admin_widgets.dart';

/// แดชบอร์ดสรุปสำหรับแอดมิน: งานที่ต้องทำ (รอตรวจสลิป/รอชำระ), ยอดรวม และจำนวนข้อมูล
/// ตัวเลขทั้งหมดคำนวณจากฐานข้อมูลสดและรีเฟรชเองทุก [_pollEvery] (ไม่ต้องกดรีเฟรช)
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key, required this.onOpenBookings, required this.refreshKey});

  /// กดการ์ดเพื่อไปแท็บการจองพร้อมตัวกรอง (pending_paid | pending_slip | confirmed | cancelled | all)
  final void Function(String filter) onOpenBookings;

  /// เปลี่ยนค่าเพื่อให้โหลดสถิติใหม่
  final int refreshKey;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  static const _pollEvery = Duration(seconds: 10);

  Map<String, dynamic>? _data;
  Object? _error;
  DateTime? _updated;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_pollEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminDashboardTab old) {
    super.didUpdateWidget(old);
    if (old.refreshKey != widget.refreshKey) _load();
  }

  // โหลดเงียบ ๆ: ถ้ารอบนี้พลาด ยังโชว์ตัวเลขล่าสุดที่มี (แสดง error เฉพาะตอนยังไม่เคยโหลดสำเร็จ)
  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final d = await ApiService.adminStats();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _updated = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  String _money(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  // กล่องสถิติสีพาสเทล: พื้นอ่อนตามสีของประเภท ไอคอน/ตัวเลข/ป้ายใช้เฉดเข้มของสีเดียวกัน
  Widget _tile({required IconData icon, required String label, required String value, required Color color, VoidCallback? onTap}) {
    final soft = Color.alphaBlend(color.withValues(alpha: 0.20), Colors.white);
    final deep = HSLColor.fromColor(color).withLightness(0.28).toColor();
    return Material(
      color: soft,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: deep, size: 20),
                  ),
                  if (onTap != null) Icon(Icons.chevron_right_rounded, color: deep.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: deep, height: 1.1)),
              Text(label, style: TextStyle(color: deep, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) {
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

    final b = Map<String, dynamic>.from(d['bookings'] as Map);
    num n(String k) => (b[k] as num?) ?? 0;
    final awaitingPay = n('pending') - n('slips_to_check');
    final stale = _error != null; // รอบล่าสุดโหลดไม่สำเร็จ → ตัวเลขอาจไม่ใช่ปัจจุบัน

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          const Text('งานที่ต้องทำ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy)),
          const SizedBox(height: 8),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 122, // ไอคอน + ตัวเลข 24 + ป้าย (ฟอนต์ไทยสูงกว่าปกติ) + padding ต้องใช้ ~115
            ),
            children: [
              _tile(icon: Icons.receipt_long_rounded, label: 'รอตรวจสลิป', value: '${n('slips_to_check')}', color: AppColors.mustard, onTap: () => widget.onOpenBookings('pending_slip')),
              _tile(icon: Icons.hourglass_empty_rounded, label: 'รอลูกค้าชำระเงิน', value: '$awaitingPay', color: AppColors.purple, onTap: () => widget.onOpenBookings('pending_paid')),
              _tile(icon: Icons.login_rounded, label: 'เช็คอินวันนี้', value: '${n('checkins_today')}', color: AppColors.adminBlue),
              _tile(icon: Icons.verified_rounded, label: 'ยืนยันแล้ว', value: '${n('confirmed')}', color: AppColors.green, onTap: () => widget.onOpenBookings('confirmed')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFCFDDF6), Color(0xFFE4ECFA)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.adminBlue.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.payments_rounded, color: AppColors.adminBlueDark, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('รายได้จากการจองที่ยืนยันแล้ว', style: TextStyle(color: AppColors.adminBlueDark, fontSize: 12.5)),
                      Text('฿${_money(n('revenue'))}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.adminBlueDark)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: stale ? AppColors.mustard : AppColors.success),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              stale ? 'เชื่อมต่อไม่ได้ — แสดงข้อมูลล่าสุดเมื่อ ${_clock(_updated!)}' : 'อัปเดตสด · ล่าสุด ${_clock(_updated!)}',
                              style: const TextStyle(color: AppColors.adminBlueDark, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tile(icon: Icons.apartment_rounded, label: 'โรงแรม', value: '${d['hotels']}', color: AppColors.teal2)),
              const SizedBox(width: 10),
              Expanded(child: _tile(icon: Icons.bed_rounded, label: 'ประเภทห้อง', value: '${d['rooms']}', color: AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _tile(icon: Icons.people_alt_rounded, label: 'ผู้ใช้', value: '${d['users']}', color: AppColors.pink)),
            ],
          ),
          const SizedBox(height: 10),
          _tile(icon: Icons.cancel_outlined, label: 'ยกเลิกทั้งหมด', value: '${n('cancelled')}', color: AppColors.danger, onTap: () => widget.onOpenBookings('cancelled')),
        ],
      ),
    );
  }
}
