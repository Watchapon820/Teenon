import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../auth/session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

/// โปรไฟล์ของผู้ใช้ที่ล็อกอินอยู่ (ข้อมูลจริงจากฐานข้อมูล) แก้ชื่อ/เบอร์โทร และเปลี่ยนรหัสผ่านได้
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController name = TextEditingController(text: Session.name);
  late final TextEditingController phone = TextEditingController(text: Session.phone);
  bool editing = false;
  bool saving = false;
  bool uploadingAvatar = false;
  int? bookingCount;
  int? confirmedCount;
  int? savedCount;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  // ดึงข้อมูลล่าสุดจากเซิร์ฟเวอร์ (ถ้าไม่ได้กำลังแก้อยู่)
  Future<void> _refresh() async {
    if (await ApiService.loadMe() && mounted && !editing) {
      setState(() {
        name.text = Session.name;
        phone.text = Session.phone;
      });
    }
    // สถิติเล็ก ๆ บนหัวโปรไฟล์ (ถ้าโหลดไม่ได้ก็แค่แสดง -)
    try {
      final bookings = await ApiService.getBookings();
      final saved = await ApiService.getSavedHotels();
      if (!mounted) return;
      setState(() {
        bookingCount = bookings.where((b) => !b.isCancelled).length;
        confirmedCount = bookings.where((b) => b.status.toLowerCase() == 'confirmed' || b.status.toLowerCase() == 'completed').length;
        savedCount = saved.length;
      });
    } catch (_) {}
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // เลือกรูปจากคลังภาพ/กล้อง แล้วอัปโหลดเป็นรูปโปรไฟล์ (ย่อให้ไม่เกิน 800 พิกเซลก่อนส่ง)
  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (file == null) return;
      setState(() => uploadingAvatar = true);
      await ApiService.uploadAvatar(file);
      if (mounted) _toast('เปลี่ยนรูปโปรไฟล์เรียบร้อยแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => uploadingAvatar = true);
    try {
      await ApiService.removeAvatar();
      if (mounted) _toast('ลบรูปโปรไฟล์แล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  void _avatarMenu() {
    if (uploadingAvatar) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('เลือกรูปจากคลังภาพ'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            // เว็บใช้กล้องผ่านตัวเลือกนี้ไม่ได้ จึงแสดงเฉพาะบนมือถือ
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('ถ่ายรูป'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
            if (Session.avatar.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('ลบรูปโปรไฟล์', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
  }

  // รูปโปรไฟล์วงกลม + ปุ่มกล้องเล็ก ๆ มุมขวาล่าง แตะเพื่อเปลี่ยนรูป
  Widget _avatar() {
    final url = ApiService.imageUrl(Session.avatar);
    return GestureDetector(
      onTap: _avatarMenu,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: Colors.white30,
            backgroundImage: url == null ? null : NetworkImage(url),
            onBackgroundImageError: url == null ? null : (_, __) {},
            child: uploadingAvatar
                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : (url == null ? const Icon(Icons.person_rounded, color: Colors.white, size: 50) : null),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
              child: const Icon(Icons.photo_camera_rounded, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return _toast('กรอกชื่อ');
    setState(() => saving = true);
    try {
      await ApiService.updateProfile(name: name.text.trim(), phone: phone.text.trim());
      if (!mounted) return;
      setState(() => editing = false);
      _toast('บันทึกข้อมูลเรียบร้อยแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      editing = false;
      name.text = Session.name;
      phone.text = Session.phone;
    });
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เปลี่ยนรหัสผ่าน'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'รหัสผ่านปัจจุบัน')),
              const SizedBox(height: 10),
              TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่ (อย่างน้อย 6 ตัว)')),
              const SizedBox(height: 10),
              TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่านใหม่')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('บันทึก')),
        ],
      ),
    );
    final currentText = current.text;
    final nextText = next.text;
    final confirmText = confirm.text;
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (ok != true) return;
    if (nextText.length < 6) return _toast('รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร');
    if (nextText != confirmText) return _toast('รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน');
    try {
      await ApiService.changePassword(currentPassword: currentText, newPassword: nextText);
      if (mounted) _toast('เปลี่ยนรหัสผ่านเรียบร้อยแล้ว');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _stat(String label, int? value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 4),
            Text(value == null ? '-' : '$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, Color color, String title, VoidCallback onTap, {String? subtitle, bool danger = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: danger ? AppColors.danger : AppColors.text)),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSoft),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    void push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    return AppShell(
      currentIndex: 4,
      title: 'บัญชีของฉัน',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // หัวโปรไฟล์: รูปอยู่กลาง ชื่อ/อีเมลใต้รูป + วงกลมตกแต่ง
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              color: AppColors.primary,
              child: Stack(
                children: [
                  Positioned(top: -40, right: -30, child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withValues(alpha: 0.10))),
                  Positioned(bottom: -50, left: -40, child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withValues(alpha: 0.10))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          _avatar(),
                          const SizedBox(height: 14),
                          Text(Session.name.isEmpty ? '-' : Session.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(Session.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFFE9DD), fontSize: 13)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('สมาชิก Teenon', style: TextStyle(color: AppColors.primaryDark, fontSize: 12.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('การจอง', bookingCount, AppColors.blue, Icons.receipt_long_rounded),
              const SizedBox(width: 10),
              _stat('ยืนยันแล้ว', confirmedCount, AppColors.green, Icons.verified_rounded),
              const SizedBox(width: 10),
              _stat('บันทึกไว้', savedCount, AppColors.purple, Icons.favorite_rounded),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('ข้อมูลส่วนตัว', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text))),
                      if (!editing)
                        TextButton.icon(
                          onPressed: saving ? null : () => setState(() => editing = true),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('แก้ไข'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: name, enabled: editing, decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded), labelText: 'ชื่อ')),
                  const SizedBox(height: 12),
                  // อีเมลเป็นตัวระบุบัญชี จึงแก้ไม่ได้
                  TextField(controller: TextEditingController(text: Session.email), enabled: false, decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded), labelText: 'อีเมล')),
                  const SizedBox(height: 12),
                  TextField(controller: phone, enabled: editing, keyboardType: TextInputType.phone, decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined), labelText: 'เบอร์โทร')),
                  if (editing) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: saving ? null : _cancelEdit,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('ยกเลิก'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: saving ? null : _save,
                            icon: const Icon(Icons.save_rounded),
                            label: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _menuTile(Icons.notifications_active_rounded, AppColors.mustard, 'การแจ้งเตือน', () => push(const NotificationsScreen()), subtitle: 'สถานะการจองและการชำระเงิน'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _menuTile(Icons.lock_rounded, AppColors.blue, 'เปลี่ยนรหัสผ่าน', _changePassword),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _menuTile(Icons.support_agent_rounded, AppColors.green, 'ติดต่อเรา / ช่วยเหลือ', () => push(const ChatScreen()), subtitle: 'แชทกับทีมงาน'),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _menuTile(Icons.tune_rounded, AppColors.purple, 'ตั้งค่า', () => push(const SettingsScreen())),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _menuTile(Icons.logout_rounded, AppColors.danger, 'ออกจากระบบ', () {
              Session.clear();
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            }, danger: true),
          ),
        ],
      ),
    );
  }
}
