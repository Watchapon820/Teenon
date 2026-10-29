/// ตัวกรอง/เรียงลำดับรายการโรงแรมในหน้า Hotels (ทำงานบนข้อมูลที่โหลดมาแล้ว)
enum HotelSort { recommended, priceLow, priceHigh, ratingHigh }

/// หมวดหมู่จากหน้า Home — จับคู่จากคำในชื่อ/ที่ตั้ง/รายละเอียด/แท็กของโรงแรม
const Map<String, List<String>> hotelCategoryKeywords = {
  'beach': ['ทะเล', 'หาด', 'ชายหาด', 'เกาะ', 'รีสอร์ท', 'รีสอร์ต', 'beach', 'sea', 'resort', 'ภูเก็ต', 'พัทยา', 'หัวหิน', 'กระบี่', 'สมุย'],
  'city': ['เมือง', 'ใจกลาง', 'city', 'downtown', 'กรุงเทพ', 'สุขุมวิท', 'สีลม'],
  'nature': ['ธรรมชาติ', 'ภูเขา', 'ดอย', 'ป่า', 'น้ำตก', 'nature', 'mountain', 'เขาใหญ่', 'เชียงใหม่', 'เชียงราย', 'ปาย'],
};

const Map<String, String> hotelCategoryTitles = {
  'deals': 'ดีลพิเศษ (ส่วนลด)',
  'beach': 'ติดทะเล',
  'city': 'ใจกลางเมือง',
  'nature': 'ใกล้ธรรมชาติ',
};

class HotelFilter {
  HotelFilter({
    this.category,
    this.maxPrice,
    this.minRating = 0,
    this.pool = false,
    this.breakfast = false,
    this.wifi = false,
    this.sort = HotelSort.recommended,
  });

  String? category;
  double? maxPrice; // null = ไม่จำกัด
  double minRating;
  bool pool;
  bool breakfast;
  bool wifi;
  HotelSort sort;

  /// จำนวนตัวกรองที่เปิดอยู่ (ไว้แสดงบนปุ่มตัวกรอง)
  int get activeCount =>
      (category != null ? 1 : 0) +
      (maxPrice != null ? 1 : 0) +
      (minRating > 0 ? 1 : 0) +
      (pool ? 1 : 0) +
      (breakfast ? 1 : 0) +
      (wifi ? 1 : 0) +
      (sort != HotelSort.recommended ? 1 : 0);

  void reset() {
    category = null;
    maxPrice = null;
    minRating = 0;
    pool = false;
    breakfast = false;
    wifi = false;
    sort = HotelSort.recommended;
  }

  static double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  /// ราคาเริ่มต้นที่ใช้เทียบ/เรียง: ถ้าโรงแรมมีดีล ใช้ราคาหลังหักส่วนลด
  static double _price(Map<String, dynamic> h) {
    final d = _num(h['deal_price']);
    return h['deal'] != null && d > 0 ? d : _num(h['starting_price']);
  }

  static double _dealPct(Map<String, dynamic> h) => h['deal'] is Map ? _num((h['deal'] as Map)['discount_percent']) : 0;
  static bool _flag(dynamic v) => v == true || v == 1 || v?.toString() == '1' || v?.toString() == 'true';

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> all, String query) {
    final q = query.trim().toLowerCase();
    final words = category == null ? const <String>[] : (hotelCategoryKeywords[category] ?? const <String>[]);
    final result = all.where((h) {
      final tags = ((h['tags'] as List?) ?? const []).join(' ');
      final haystack = '${h['name']} ${h['location']} ${h['description'] ?? ''} $tags'.toLowerCase();
      if (q.isNotEmpty && !haystack.contains(q)) return false;
      if (words.isNotEmpty && !words.any((w) => haystack.contains(w.toLowerCase()))) return false;
      // หมวด "ดีล" แสดงเฉพาะโรงแรมที่มีดีลที่ใช้ได้อยู่ตอนนี้
      if (category == 'deals' && h['deal'] == null) return false;
      final price = _price(h);
      if (maxPrice != null && (price <= 0 || price > maxPrice!)) return false;
      if (minRating > 0 && _num(h['rating']) < minRating) return false;
      if (pool && !_flag(h['has_pool'])) return false;
      if (breakfast && !_flag(h['has_breakfast'])) return false;
      if (wifi && !_flag(h['has_wifi'])) return false;
      return true;
    }).toList();

    int byPrice(Map<String, dynamic> a, Map<String, dynamic> b) {
      // โรงแรมที่ยังไม่มีราคา (0) ไปท้ายสุด
      final pa = _price(a);
      final pb = _price(b);
      if (pa <= 0 && pb <= 0) return 0;
      if (pa <= 0) return 1;
      if (pb <= 0) return -1;
      return pa.compareTo(pb);
    }

    // หมวดดีล (ไม่ได้เลือกเรียงเอง): เรียงส่วนลดมากสุดก่อน
    if (category == 'deals' && sort == HotelSort.recommended) {
      result.sort((a, b) => _dealPct(b).compareTo(_dealPct(a)));
      return result;
    }
    switch (sort) {
      case HotelSort.priceLow:
        result.sort(byPrice);
      case HotelSort.priceHigh:
        result.sort((a, b) {
          final pa = _price(a);
          final pb = _price(b);
          if (pa <= 0 && pb <= 0) return 0;
          if (pa <= 0) return 1;
          if (pb <= 0) return -1;
          return pb.compareTo(pa);
        });
      case HotelSort.ratingHigh:
        result.sort((a, b) => _num(b['rating']).compareTo(_num(a['rating'])));
      case HotelSort.recommended:
        break;
    }
    return result;
  }
}
