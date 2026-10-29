import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// เก็บข้อมูลผู้ใช้ที่ล็อกอินอยู่ — token ถูกจำไว้ในเครื่อง เปิดแอปใหม่จึงไม่ต้องล็อกอินซ้ำ
class Session {
  static const _tokenKey = 'teenon_token';

  static String? token;
  static int? userId;
  static String name = '';
  static String email = '';
  static String phone = '';
  static String role = 'user';
  static String avatar = ''; // path รูปโปรไฟล์ เช่น /uploads/avatars/xxx.jpg (ว่าง = ยังไม่มีรูป)

  /// true เมื่อผู้ใช้ที่ล็อกอินเป็นแอดมิน — แอปฟังค่านี้เพื่อสลับเป็นธีมสีฟ้า
  static final ValueNotifier<bool> adminMode = ValueNotifier(false);

  static bool get isLoggedIn => token != null;
  static bool get isAdmin => role == 'admin';

  static void setFromResponse(Map<String, dynamic> body) {
    token = body['token'] as String;
    updateUser(Map<String, dynamic>.from(body['user']));
    _save();
  }

  /// อัปเดตข้อมูลผู้ใช้จากเซิร์ฟเวอร์ (เช่น หลังแก้โปรไฟล์)
  static void updateUser(Map<String, dynamic> user) {
    userId = (user['id'] as num).toInt();
    name = (user['name'] ?? '').toString();
    email = (user['email'] ?? '').toString();
    phone = (user['phone'] ?? '').toString();
    role = (user['role'] ?? 'user').toString();
    avatar = (user['avatar'] ?? '').toString();
    adminMode.value = isAdmin;
  }

  /// โหลด token ที่เคยบันทึกไว้ (เรียกตอนเปิดแอป) แล้วตรวจกับเซิร์ฟเวอร์ต่อ
  static Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
    } catch (_) {
      token = null;
    }
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, token!);
      }
    } catch (_) {}
  }

  static void clear() {
    token = null;
    userId = null;
    name = '';
    email = '';
    phone = '';
    role = 'user';
    avatar = '';
    adminMode.value = false;
    _save();
  }
}
