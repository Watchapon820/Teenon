/// ข้อมูลการจองที่อ่านจากฐานข้อมูล (ตาราง bookings) ผ่าน GET /api/bookings
class BookingRecord {
  const BookingRecord({
    required this.code,
    required this.hotelName,
    required this.roomName,
    required this.guestName,
    required this.checkIn,
    required this.checkOut,
    required this.numGuests,
    required this.numRooms,
    required this.total,
    required this.status,
    this.hotelId,
    this.hotelImage,
    this.hasSlip = false,
    this.hasReview = false,
    this.paymentMethod,
    this.cancelBlock,
  });

  final String code;
  final String hotelName;
  final String roomName;
  final String guestName;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int numGuests;
  final int numRooms;
  final int total;
  final String status;
  final int? hotelId;

  /// path รูปโรงแรม (เช่น /uploads/xxx.jpg) ใช้เป็นพื้นหลังการ์ด — ว่าง/null = ใช้สีไล่แทน
  final String? hotelImage;
  final bool hasSlip;
  final bool hasReview;
  final String? paymentMethod;

  /// เหตุผลที่ลูกค้ายกเลิกรายการนี้ไม่ได้ตามนโยบายของโรงแรม (null = ยกเลิกได้) — คำนวณที่ server
  final String? cancelBlock;

  static const List<String> _months = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  factory BookingRecord.fromJson(Map<String, dynamic> j) {
    return BookingRecord(
      code: (j['booking_code'] ?? '').toString(),
      hotelName: (j['hotel_name'] ?? '').toString(),
      roomName: (j['room_label'] ?? 'ห้องพัก').toString(),
      guestName: (j['guest_name'] ?? '').toString(),
      checkIn: _parseDate(j['check_in_date']),
      checkOut: _parseDate(j['check_out_date']),
      numGuests: int.tryParse('${j['num_guests']}') ?? 1,
      numRooms: int.tryParse('${j['num_rooms']}') ?? 1,
      total: (double.tryParse('${j['total_amount']}') ?? 0).round(),
      status: (j['status'] ?? 'confirmed').toString(),
      hotelId: int.tryParse('${j['hotel_id']}'),
      hotelImage: (j['hotel_image'] ?? '').toString().isEmpty ? null : j['hotel_image'].toString(),
      hasSlip: j['has_slip'] == true || '${j['has_slip']}' == '1',
      hasReview: j['has_review'] == true || '${j['has_review']}' == '1',
      paymentMethod: j['payment_method']?.toString(),
      cancelBlock: j['cancel_block']?.toString(),
    );
  }

  // รับได้ทั้ง '2026-09-26' และ '2026-09-26T00:00:00.000Z' (ใช้เฉพาะ 10 ตัวอักษรแรก)
  static DateTime? _parseDate(dynamic v) {
    final s = v?.toString();
    if (s == null || s.length < 10) return null;
    return DateTime.tryParse(s.substring(0, 10));
  }

  bool get isCancelled {
    final s = status.toLowerCase();
    return s == 'cancelled' || s == 'canceled';
  }

  /// รีวิวได้เมื่อยืนยันแล้ว ถึงวันเข้าพักแล้ว และยังไม่เคยรีวิว
  bool get canReview {
    if (hasReview || status.toLowerCase() != 'confirmed') return false;
    final ci = checkIn;
    if (ci == null) return false;
    final now = DateTime.now();
    return !DateTime(ci.year, ci.month, ci.day).isAfter(DateTime(now.year, now.month, now.day));
  }

  /// รอชำระเงิน = รอยืนยันและยังไม่ส่งสลิป
  bool get awaitingPayment => isPending && !hasSlip;

  bool get isPending => status.toLowerCase() == 'pending';

  /// ข้อความสถานะที่แสดงให้ผู้ใช้
  String get statusText => isCancelled ? 'ยกเลิกแล้ว' : (isPending ? (hasSlip ? 'รอตรวจสลิป' : 'รอชำระเงิน') : 'ยืนยันแล้ว');

  int get nights {
    if (checkIn == null || checkOut == null) return 0;
    return checkOut!.difference(checkIn!).inDays;
  }

  static String _fmt(DateTime? d) => d == null ? '-' : '${d.day} ${_months[d.month - 1]} ${d.year}';

  String get checkInText => _fmt(checkIn);
  String get checkOutText => _fmt(checkOut);

  /// เช่น "20–22 Aug 2026" (ถ้าคนละเดือนจะแสดงวันที่เต็มทั้งสองฝั่ง)
  String get dateRangeText {
    final a = checkIn;
    final b = checkOut;
    if (a == null || b == null) return '-';
    if (a.year == b.year && a.month == b.month) {
      return '${a.day}–${b.day} ${_months[a.month - 1]} ${a.year}';
    }
    return '${_fmt(a)} – ${_fmt(b)}';
  }
}