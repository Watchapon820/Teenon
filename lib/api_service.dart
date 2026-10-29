import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth/session.dart';
import 'models/booking_record.dart';

/// client ที่มีเวลารอสูงสุด: ถ้าเชื่อมต่อ server ไม่ได้/ช้าเกินไป จะแจ้งข้อความที่อ่านเข้าใจ แทนที่จะค้างรอไม่รู้จบ
class _TimeoutClient extends http.BaseClient {
  _TimeoutClient(this._inner);

  final http.Client _inner;
  static const _limit = Duration(seconds: 30); // เผื่ออัปโหลดรูปบนเน็ตช้า

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await _inner.send(request).timeout(_limit);
    } on TimeoutException {
      throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ (หมดเวลารอ) กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่');
    } on http.ClientException {
      throw Exception('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่');
    }
  }
}

final http.Client _client = _TimeoutClient(http.Client());

class ApiService {
  // เลือก baseUrl อัตโนมัติตามแพลตฟอร์ม
  // - Flutter Web / Desktop / iOS Simulator: localhost
  // - Android Emulator: 10.0.2.2
  // - มือถือจริง: เปลี่ยนเป็น IP ของคอมในวง Wi-Fi เดียวกัน เช่น http://192.168.1.x:5000/api
  // ตั้งตอนรัน/build ได้: flutter run --dart-define=API_BASE_URL=https://api.example.com/api
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:5000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  // ที่อยู่ server ที่แอปนี้เรียกอยู่ (host[:port]) — แสดงในหน้าล็อกอินไว้ตรวจว่า build ชี้ถูกที่หรือไม่
  static String get serverHost => Uri.parse(baseUrl).authority;

  // ทดสอบการเชื่อมต่อ server: คืนเวลาที่ใช้ (ms) หรือ throw Exception ที่บอกสาเหตุ
  static Future<int> ping() async {
    final sw = Stopwatch()..start();
    final response = await _client.get(Uri.parse('$baseUrl/ping'));
    if (response.statusCode != 200) throw Exception('เซิร์ฟเวอร์ตอบกลับผิดปกติ (HTTP ${response.statusCode})');
    return sw.elapsedMilliseconds;
  }

  // แปลง path รูปจาก server (เช่น /uploads/a.jpg) เป็น URL เต็ม; คืน null ถ้าไม่มีรูป
  static String? imageUrl(dynamic path) {
    final p = path?.toString() ?? '';
    if (p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return baseUrl.replaceFirst(RegExp(r'/api$'), '') + p;
  }

  // header แนบ token ของผู้ที่ล็อกอินอยู่ทุกครั้ง
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (Session.token != null) 'Authorization': 'Bearer ${Session.token}',
      };

  // 0. สมัครสมาชิก / เข้าสู่ระบบ (สำเร็จแล้วเก็บ token + role ลง Session)
  static Future<void> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password, 'phone': phone}),
    );
    if (response.statusCode == 201) {
      Session.setFromResponse(Map<String, dynamic>.from(_decode(response)));
      return;
    }
    throw Exception(_errorMessage(response, 'สมัครสมาชิกไม่สำเร็จ'));
  }

  static Future<void> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode == 200) {
      Session.setFromResponse(Map<String, dynamic>.from(_decode(response)));
      return;
    }
    throw Exception(_errorMessage(response, 'เข้าสู่ระบบไม่สำเร็จ'));
  }

  // ลืมรหัสผ่าน: ตรวจว่ามีอีเมลนี้ในระบบหรือไม่ (ไม่พบ = throw) คืน true ถ้าต้องกรอกเบอร์โทรยืนยันด้วย
  // ขอรหัสยืนยัน 6 หลักทางอีเมล (server ตอบเหมือนกันไม่ว่าจะมีอีเมลนี้หรือไม่)
  static Future<void> forgotPassword(String email) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ส่งรหัสยืนยันไม่สำเร็จ'));
  }

  static Future<void> resetPassword({required String email, required String code, required String password}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'password': password}),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ'));
  }

  // ตรวจ token ที่จำไว้ และดึงข้อมูลผู้ใช้ล่าสุด (คืน false ถ้า token หมดอายุ/ใช้ไม่ได้)
  static Future<bool> loadMe() async {
    if (Session.token == null) return false;
    try {
      final response = await _client.get(Uri.parse('$baseUrl/me'), headers: _headers);
      if (response.statusCode == 200) {
        Session.updateUser(Map<String, dynamic>.from(_decode(response)['user']));
        return true;
      }
      if (response.statusCode == 401 || response.statusCode == 404) Session.clear();
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> updateProfile({required String name, required String phone}) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/me'),
      headers: _headers,
      body: jsonEncode({'name': name, 'phone': phone}),
    );
    if (response.statusCode == 200) {
      Session.updateUser(Map<String, dynamic>.from(_decode(response)['user']));
      return;
    }
    throw Exception(_errorMessage(response, 'บันทึกข้อมูลไม่สำเร็จ'));
  }

  // เปลี่ยนรูปโปรไฟล์ (ส่งเป็น base64) สำเร็จแล้วอัปเดต Session.avatar
  static Future<void> uploadAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    final response = await _client.put(
      Uri.parse('$baseUrl/me/avatar'),
      headers: _headers,
      body: jsonEncode({'data': base64Encode(bytes)}),
    );
    if (response.statusCode == 200) {
      Session.avatar = (_decode(response)['avatar'] ?? '').toString();
      return;
    }
    throw Exception(_errorMessage(response, 'อัปโหลดรูปไม่สำเร็จ'));
  }

  static Future<void> removeAvatar() async {
    final response = await _client.delete(Uri.parse('$baseUrl/me/avatar'), headers: _headers);
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ลบรูปไม่สำเร็จ'));
    Session.avatar = '';
  }

  static Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/me/password'),
      headers: _headers,
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'เปลี่ยนรหัสผ่านไม่สำเร็จ'));
  }

  // แปลง response เป็น JSON (รองรับภาษาไทย)
  static dynamic _decode(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // ดึงข้อความ error จาก server ({ success:false, message:"..." })
  static String _errorMessage(http.Response response, String fallback) {
    try {
      final body = _decode(response);
      if (body is Map && body['message'] != null && body['message'].toString().trim().isNotEmpty) {
        return body['message'].toString();
      }
    } catch (_) {}
    // server ไม่ได้ตอบเป็น JSON (เช่น ไม่พบ route) แสดงรหัสสถานะเพื่อช่วยหาสาเหตุ
    return '$fallback (HTTP ${response.statusCode})';
  }

  // 1. ดึงรายการโรงแรม
  static Future<List<Map<String, dynamic>>> getHotels() async {
    final response = await _client.get(Uri.parse('$baseUrl/hotels'));

    if (response.statusCode == 200) {
      final data = _decode(response)['data'] as List;
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(_errorMessage(response, 'Failed to load hotels'));
  }

  // โรงแรมที่ผู้ใช้กดดาวบันทึกไว้
  static Future<List<Map<String, dynamic>>> getSavedHotels() async {
    final response = await _client.get(Uri.parse('$baseUrl/saved'), headers: _headers);
    if (response.statusCode == 200) {
      return (_decode(response)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(_errorMessage(response, 'โหลดโรงแรมที่บันทึกไม่สำเร็จ'));
  }

  static Future<void> setHotelSaved(int hotelId, bool saved) async {
    final uri = Uri.parse('$baseUrl/saved/$hotelId');
    final response = saved ? await _client.put(uri, headers: _headers) : await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'บันทึกโรงแรมไม่สำเร็จ'));
  }

  // 2. ดึงรายละเอียดโรงแรม (มี rooms และ tags)
  // ส่ง checkIn/checkOut (YYYY-MM-DD) เพื่อให้ rooms_available ของแต่ละห้องคิดตามช่วงวันที่นั้น (ไม่ส่ง = คืนนี้)
  static Future<Map<String, dynamic>> getHotelById(int id, {String? checkIn, String? checkOut}) async {
    final query = <String, String>{if (checkIn != null) 'checkIn': checkIn, if (checkOut != null) 'checkOut': checkOut};
    final response = await _client.get(Uri.parse('$baseUrl/hotels/$id').replace(queryParameters: query.isEmpty ? null : query));

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(_decode(response)['data']);
    }
    throw Exception(_errorMessage(response, 'Failed to load hotel'));
  }

  // 3. ส่งข้อมูลการจอง
  static Future<Map<String, dynamic>> createBooking(
      Map<String, dynamic> bookingData) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/bookings'),
      headers: _headers,
      body: jsonEncode(bookingData),
    );

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(_decode(response));
    }
    throw Exception(_errorMessage(response, 'Failed to create booking'));
  }

  // 4. เพิ่มโรงแรมใหม่ (สำหรับหน้าแอดมิน)
  static Future<Map<String, dynamic>> createHotel(
      Map<String, dynamic> hotelData) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/hotels'),
      headers: _headers,
      body: jsonEncode(hotelData),
    );

    if (response.statusCode == 201) {
      return Map<String, dynamic>.from(_decode(response));
    }
    throw Exception(_errorMessage(response, 'Failed to create hotel'));
  }

  // 5. ดึงรายการจองของผู้ใช้ (ล่าสุดอยู่บนสุด)
  static Future<List<BookingRecord>> getBookings() async {
    final response = await _client.get(Uri.parse('$baseUrl/bookings'), headers: _headers);

    if (response.statusCode == 200) {
      final data = _decode(response)['data'] as List;
      return data
          .map((e) => BookingRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_errorMessage(response, 'Failed to load bookings'));
  }

  // 6. ยกเลิกการจองตามรหัสจอง (เช่น TN-7KQ4M2XA)
  // server จะเปลี่ยน status เป็น cancelled และบันทึกเหตุผลลงตาราง cancellations
  static Future<void> cancelBooking(
    String bookingCode, {
    String reason = '',
    String details = '',
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/bookings/${Uri.encodeComponent(bookingCode)}/cancel'),
      headers: _headers,
      body: jsonEncode({'reason': reason, 'additionalDetails': details}),
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to cancel booking'));
    }
  }

  // ===== รีวิว =====
  static Future<Map<String, dynamic>> getHotelReviews(int hotelId) async {
    final response = await _client.get(Uri.parse('$baseUrl/hotels/$hotelId/reviews'));
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response));
    throw Exception(_errorMessage(response, 'โหลดรีวิวไม่สำเร็จ'));
  }

  static Future<void> submitReview({required String bookingCode, required int rating, String comment = ''}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/reviews'),
      headers: _headers,
      body: jsonEncode({'bookingCode': bookingCode, 'rating': rating, 'comment': comment}),
    );
    if (response.statusCode != 201) throw Exception(_errorMessage(response, 'ส่งรีวิวไม่สำเร็จ'));
  }

  // ===== แจ้งเตือน =====
  static Future<Map<String, dynamic>> getNotifications() async {
    final response = await _client.get(Uri.parse('$baseUrl/notifications'), headers: _headers);
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response));
    throw Exception(_errorMessage(response, 'โหลดการแจ้งเตือนไม่สำเร็จ'));
  }

  static Future<void> markNotificationsRead() async {
    await _client.put(Uri.parse('$baseUrl/notifications/read'), headers: _headers);
  }

  // ===== ชำระเงิน =====
  static Future<Map<String, dynamic>> getPaymentInfo(String bookingCode) async {
    final response = await _client.get(Uri.parse('$baseUrl/bookings/${Uri.encodeComponent(bookingCode)}/payment-info'), headers: _headers);
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response));
    throw Exception(_errorMessage(response, 'โหลดข้อมูลการชำระเงินไม่สำเร็จ'));
  }

  static Future<void> submitPayment({required String bookingCode, required String method, required XFile slip}) async {
    final bytes = await slip.readAsBytes();
    final response = await _client.post(
      Uri.parse('$baseUrl/bookings/${Uri.encodeComponent(bookingCode)}/payment'),
      headers: _headers,
      body: jsonEncode({'method': method, 'slip': base64Encode(bytes)}),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ส่งสลิปไม่สำเร็จ'));
  }

  // ดึงรูปสลิป (เจ้าของรายการหรือแอดมินเท่านั้น)
  static Future<Uint8List> getSlip(String bookingCode) async {
    final response = await _client.get(Uri.parse('$baseUrl/bookings/${Uri.encodeComponent(bookingCode)}/slip'), headers: _headers);
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception(_errorMessage(response, 'โหลดสลิปไม่สำเร็จ'));
  }

  // ข้อมูลติดต่อที่แอดมินตั้งไว้ในเซิร์ฟเวอร์
  static Future<Map<String, dynamic>> getContact() async {
    final response = await _client.get(Uri.parse('$baseUrl/config'));
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response)['contact'] ?? {});
    throw Exception(_errorMessage(response, 'โหลดข้อมูลติดต่อไม่สำเร็จ'));
  }

  // ===== แชทกับทีมงาน (ลูกค้า) =====
  // ดึงข้อความใหม่ที่ id > after คืน { data: [...], read_up_to: id ข้อความของเราที่ทีมงานอ่านถึง }
  static Future<Map<String, dynamic>> chatMessages({int after = 0}) async {
    final response = await _client.get(Uri.parse('$baseUrl/chat?after=$after'), headers: _headers);
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response));
    throw Exception(_errorMessage(response, 'โหลดข้อความไม่สำเร็จ'));
  }

  static Future<void> chatSend(String body) async {
    final response = await _client.post(Uri.parse('$baseUrl/chat'), headers: _headers, body: jsonEncode({'body': body}));
    if (response.statusCode != 201) throw Exception(_errorMessage(response, 'ส่งข้อความไม่สำเร็จ'));
  }

  // จำนวนข้อความจากทีมงานที่ยังไม่ได้อ่าน (0 ถ้าโหลดไม่สำเร็จ)
  static Future<int> chatUnread() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/chat/unread'), headers: _headers);
      if (response.statusCode == 200) return (_decode(response)['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    return 0;
  }

  // ===== แชท (แอดมิน) =====
  static Future<List<Map<String, dynamic>>> adminChats() async {
    final response = await _client.get(Uri.parse('$baseUrl/admin/chats'), headers: _headers);
    if (response.statusCode == 200) return (_decode(response)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    throw Exception(_errorMessage(response, 'โหลดแชทไม่สำเร็จ'));
  }

  static Future<Map<String, dynamic>> adminChatMessages(int userId, {int after = 0}) async {
    final response = await _client.get(Uri.parse('$baseUrl/admin/chats/$userId?after=$after'), headers: _headers);
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response));
    throw Exception(_errorMessage(response, 'โหลดข้อความไม่สำเร็จ'));
  }

  static Future<void> adminChatSend(int userId, String body) async {
    final response = await _client.post(Uri.parse('$baseUrl/admin/chats/$userId'), headers: _headers, body: jsonEncode({'body': body}));
    if (response.statusCode != 201) throw Exception(_errorMessage(response, 'ส่งข้อความไม่สำเร็จ'));
  }

  // จำนวนข้อความจากลูกค้าที่แอดมินยังไม่ได้อ่าน
  static Future<int> adminChatUnread() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/admin/chats/unread'), headers: _headers);
      if (response.statusCode == 200) return (_decode(response)['unread'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    return 0;
  }

  // ===== เฉพาะแอดมิน =====
  // ===== ดีล/โปรโมชัน (แอดมิน) =====
  static Future<List<Map<String, dynamic>>> adminGetDeals() async {
    final response = await _client.get(Uri.parse('$baseUrl/admin/deals'), headers: _headers);
    if (response.statusCode == 200) return (_decode(response)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    throw Exception(_errorMessage(response, 'โหลดดีลไม่สำเร็จ'));
  }

  // สร้างดีล (id = null) หรือแก้ดีล (ส่งเฉพาะฟิลด์ที่ต้องการแก้ได้)
  static Future<void> adminSaveDeal({int? id, required Map<String, dynamic> fields}) async {
    final uri = Uri.parse(id == null ? '$baseUrl/admin/deals' : '$baseUrl/admin/deals/$id');
    final response = id == null
        ? await _client.post(uri, headers: _headers, body: jsonEncode(fields))
        : await _client.put(uri, headers: _headers, body: jsonEncode(fields));
    if (response.statusCode != 200 && response.statusCode != 201) throw Exception(_errorMessage(response, 'บันทึกดีลไม่สำเร็จ'));
  }

  static Future<void> adminDeleteDeal(int id) async {
    final response = await _client.delete(Uri.parse('$baseUrl/admin/deals/$id'), headers: _headers);
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ลบดีลไม่สำเร็จ'));
  }

  // date (YYYY-MM-DD) = คืนที่ต้องการดูห้องว่าง ไม่ส่ง = คืนนี้
  static Future<List<Map<String, dynamic>>> adminGetRooms({String? date}) async {
    final uri = Uri.parse('$baseUrl/admin/rooms').replace(queryParameters: date == null ? null : {'date': date});
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return (_decode(response)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(_errorMessage(response, 'โหลดห้องพักไม่สำเร็จ'));
  }

  // อัปโหลดรูป คืน path เช่น /uploads/xxx.jpg เพื่อนำไปบันทึกกับโรงแรม/ห้อง
  static Future<String> adminUploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/upload'),
      headers: _headers,
      body: jsonEncode({'data': base64Encode(bytes), 'ext': ext}),
    );
    if (response.statusCode == 201) return _decode(response)['url'].toString();
    throw Exception(_errorMessage(response, 'อัปโหลดรูปไม่สำเร็จ'));
  }

  static Future<void> adminUpdateHotel(int id, Map<String, dynamic> fields) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/admin/hotels/$id'),
      headers: _headers,
      body: jsonEncode(fields),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'แก้ไขโรงแรมไม่สำเร็จ'));
  }

  static Future<void> adminAddRoom({
    required int hotelId,
    required String name,
    required num price,
    String? imageUrl,
    int? quantity,
    int? maxGuests,
    String? bedType,
    int? sizeSqm,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/rooms'),
      headers: _headers,
      body: jsonEncode({
        'hotelId': hotelId,
        'name': name,
        'price': price,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (quantity != null) 'quantity': quantity,
        if (maxGuests != null) 'maxGuests': maxGuests,
        if (bedType != null) 'bedType': bedType,
        if (sizeSqm != null) 'sizeSqm': sizeSqm,
      }),
    );
    if (response.statusCode != 201) throw Exception(_errorMessage(response, 'เพิ่มห้องไม่สำเร็จ'));
  }

  static Future<void> adminUpdateRoom(
    int id, {
    String? name,
    num? price,
    String? imageUrl,
    int? quantity,
    int? maxGuests,
    String? bedType,
    int? sizeSqm,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/admin/rooms/$id'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (price != null) 'price': price,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (quantity != null) 'quantity': quantity,
        if (maxGuests != null) 'maxGuests': maxGuests,
        if (bedType != null) 'bedType': bedType,
        if (sizeSqm != null) 'sizeSqm': sizeSqm,
      }),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'แก้ไขห้องไม่สำเร็จ'));
  }

  // เพิ่ม/ลดจำนวนห้องที่มี (delta = +1 / -1) คืนข้อมูลล่าสุดของห้อง: quantity, booked_tonight, rooms_available
  static Future<Map<String, dynamic>> adminAdjustRoomQuantity(int id, int delta) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/admin/rooms/$id/quantity'),
      headers: _headers,
      body: jsonEncode({'delta': delta}),
    );
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response));
    throw Exception(_errorMessage(response, 'ปรับจำนวนห้องไม่สำเร็จ'));
  }

  static Future<void> adminDeleteRoom(int id) async {
    final response = await _client.delete(Uri.parse('$baseUrl/admin/rooms/$id'), headers: _headers);
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ลบห้องไม่สำเร็จ'));
  }

  static Future<void> adminConfirmBooking(String bookingCode) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/admin/bookings/${Uri.encodeComponent(bookingCode)}/confirm'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ยืนยันการจองไม่สำเร็จ'));
  }

  static Future<List<Map<String, dynamic>>> adminGetBookings() async {
    final response = await _client.get(Uri.parse('$baseUrl/admin/bookings'), headers: _headers);
    if (response.statusCode == 200) {
      return (_decode(response)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(_errorMessage(response, 'โหลดรายการจองไม่สำเร็จ'));
  }

  static Future<void> adminDeleteHotel(int id) async {
    final response = await _client.delete(Uri.parse('$baseUrl/admin/hotels/$id'), headers: _headers);
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ลบโรงแรมไม่สำเร็จ'));
  }

  static Future<void> adminSetTags(int hotelId, List<String> tags) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/admin/hotels/$hotelId/tags'),
      headers: _headers,
      body: jsonEncode({'tags': tags}),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'บันทึกแท็กไม่สำเร็จ'));
  }

  static Future<List<Map<String, dynamic>>> adminGetHotelImages(int hotelId) async {
    final response = await _client.get(Uri.parse('$baseUrl/admin/hotels/$hotelId/images'), headers: _headers);
    if (response.statusCode == 200) {
      return (_decode(response)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(_errorMessage(response, 'โหลดรูปไม่สำเร็จ'));
  }

  static Future<void> adminAddHotelImage(int hotelId, XFile file) async {
    final url = await adminUploadImage(file);
    final response = await _client.post(
      Uri.parse('$baseUrl/admin/hotels/$hotelId/images'),
      headers: _headers,
      body: jsonEncode({'imageUrl': url}),
    );
    if (response.statusCode != 201) throw Exception(_errorMessage(response, 'เพิ่มรูปไม่สำเร็จ'));
  }

  static Future<void> adminDeleteHotelImage(int imageId) async {
    final response = await _client.delete(Uri.parse('$baseUrl/admin/hotel-images/$imageId'), headers: _headers);
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ลบรูปไม่สำเร็จ'));
  }

  static Future<Map<String, dynamic>> adminStats() async {
    final response = await _client.get(Uri.parse('$baseUrl/admin/stats'), headers: _headers);
    if (response.statusCode == 200) return Map<String, dynamic>.from(_decode(response));
    throw Exception(_errorMessage(response, 'โหลดสถิติไม่สำเร็จ'));
  }

  // แอดมินปฏิเสธ/ยกเลิกการจองแทนลูกค้า
  static Future<void> adminCancelBooking(String bookingCode, {required String reason}) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/admin/bookings/${Uri.encodeComponent(bookingCode)}/cancel'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) throw Exception(_errorMessage(response, 'ยกเลิกการจองไม่สำเร็จ'));
  }
}
