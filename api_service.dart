import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // หมายเหตุ: สำหรับ Android Emulator ให้เปลี่ยน localhost เป็น 10.0.2.2
  static const String baseUrl = 'http://localhost:5000/api'; 

  // 1. ดึงรายการโรงแรม
  static Future<List<dynamic>> getHotels() async {
    final response = await http.get(Uri.parse('$baseUrl/hotels'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load hotels');
    }
  }

  // 2. ส่งข้อมูลการจอง
  static Future<Map<String, dynamic>> createBooking(Map<String, dynamic> bookingData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bookingData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create booking');
    }
  }
}