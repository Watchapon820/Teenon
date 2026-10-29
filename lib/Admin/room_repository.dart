import '../api_service.dart';

/// ข้อมูลห้องพักที่หน้าแอดมินใช้
class RoomItem {
  const RoomItem({
    required this.id,
    required this.hotelId,
    required this.hotelName,
    required this.name,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
    this.bookedTonight = 0,
    this.pending = 0,
    this.maxGuests,
    this.bedType,
    this.sizeSqm,
  });

  final int id;
  final int hotelId;
  final String hotelName;
  final String name;
  final num price;
  final String? imageUrl;
  final int quantity;

  /// ห้องที่แอดมิน "ยืนยันแล้ว" ในคืนที่ดู → ห้องว่าง = quantity - bookedTonight
  final int bookedTonight;

  /// ห้องที่ลูกค้าจองแล้วแต่ยังรอยืนยัน (ยังไม่ลดห้องว่าง)
  final int pending;
  final int? maxGuests;
  final String? bedType;
  final int? sizeSqm;

  int get available => (quantity - bookedTonight).clamp(0, quantity);

  RoomItem withQuantity(int quantity, int bookedTonight) => RoomItem(
        id: id,
        hotelId: hotelId,
        hotelName: hotelName,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity,
        bookedTonight: bookedTonight,
        pending: pending,
        maxGuests: maxGuests,
        bedType: bedType,
        sizeSqm: sizeSqm,
      );

  factory RoomItem.fromJson(Map<String, dynamic> j) => RoomItem(
        id: (j['room_id'] as num).toInt(),
        hotelId: (j['hotel_id'] as num).toInt(),
        hotelName: (j['hotel_name'] ?? '-').toString(),
        name: (j['name'] ?? 'ห้องพัก').toString(),
        price: num.tryParse('${j['price_per_night']}') ?? 0,
        imageUrl: ApiService.imageUrl(j['image_url']),
        quantity: int.tryParse('${j['quantity']}') ?? 1,
        bookedTonight: int.tryParse('${j['booked_tonight']}') ?? 0,
        pending: int.tryParse('${j['pending_tonight']}') ?? 0,
        maxGuests: int.tryParse('${j['max_guests']}'),
        bedType: (j['bed_type'] ?? '').toString().isEmpty ? null : j['bed_type'].toString(),
        sizeSqm: int.tryParse('${j['size_sqm']}'),
      );
}

abstract class RoomRepository {
  /// date (YYYY-MM-DD) = คืนที่ต้องการดูห้องว่าง ไม่ส่ง = คืนนี้
  Future<List<RoomItem>> listRooms({String? date});
  Future<void> addRoom({required int hotelId, required String name, required num price, String? imageUrl, int? quantity, int? maxGuests, String? bedType, int? sizeSqm});
  Future<void> updateRoom(int id, {String? name, num? price, String? imageUrl, int? quantity, int? maxGuests, String? bedType, int? sizeSqm});
  Future<void> deleteRoom(int id);

  /// เพิ่ม/ลดจำนวนห้องที่มี (delta = +1 / -1) คืนห้องที่อัปเดตแล้ว
  Future<RoomItem> adjustQuantity(RoomItem room, int delta);
}

/// เชื่อมฐานข้อมูลจริงผ่าน backend (ใช้ตอนล็อกอินเป็นแอดมิน)
class ApiRoomRepository implements RoomRepository {
  @override
  Future<List<RoomItem>> listRooms({String? date}) async =>
      (await ApiService.adminGetRooms(date: date)).map(RoomItem.fromJson).toList();

  @override
  Future<void> addRoom({required int hotelId, required String name, required num price, String? imageUrl, int? quantity, int? maxGuests, String? bedType, int? sizeSqm}) =>
      ApiService.adminAddRoom(
        hotelId: hotelId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity,
        maxGuests: maxGuests,
        bedType: bedType,
        sizeSqm: sizeSqm,
      );

  @override
  Future<void> updateRoom(int id, {String? name, num? price, String? imageUrl, int? quantity, int? maxGuests, String? bedType, int? sizeSqm}) =>
      ApiService.adminUpdateRoom(
        id,
        name: name,
        price: price,
        imageUrl: imageUrl,
        quantity: quantity,
        maxGuests: maxGuests,
        bedType: bedType,
        sizeSqm: sizeSqm,
      );

  @override
  Future<void> deleteRoom(int id) => ApiService.adminDeleteRoom(id);

  @override
  Future<RoomItem> adjustQuantity(RoomItem room, int delta) async {
    final r = await ApiService.adminAdjustRoomQuantity(room.id, delta);
    return room.withQuantity(int.tryParse('${r['quantity']}') ?? room.quantity, int.tryParse('${r['booked_tonight']}') ?? room.bookedTonight);
  }
}

/// เก็บในหน่วยความจำ (ไว้ทดสอบ/รัน main_admin.dart แยกโดยไม่ต้องมี server)
class MemoryRoomRepository implements RoomRepository {
  final List<RoomItem> _rooms = [
    const RoomItem(id: 1, hotelId: 1, hotelName: 'Demo Hotel', name: 'Deluxe', price: 1500),
  ];
  int _next = 2;

  @override
  Future<List<RoomItem>> listRooms({String? date}) async => List.of(_rooms);

  @override
  Future<void> addRoom({required int hotelId, required String name, required num price, String? imageUrl, int? quantity, int? maxGuests, String? bedType, int? sizeSqm}) async {
    _rooms.add(RoomItem(id: _next++, hotelId: hotelId, hotelName: 'Hotel #$hotelId', name: name, price: price));
  }

  @override
  Future<void> updateRoom(int id, {String? name, num? price, String? imageUrl, int? quantity, int? maxGuests, String? bedType, int? sizeSqm}) async {
    final i = _rooms.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = _rooms[i];
    _rooms[i] = RoomItem(id: r.id, hotelId: r.hotelId, hotelName: r.hotelName, name: name ?? r.name, price: price ?? r.price);
  }

  @override
  Future<void> deleteRoom(int id) async => _rooms.removeWhere((r) => r.id == id);

  @override
  Future<RoomItem> adjustQuantity(RoomItem room, int delta) async {
    final i = _rooms.indexWhere((r) => r.id == room.id);
    final next = (room.quantity + delta).clamp(0, 9999);
    final updated = room.withQuantity(next, room.bookedTonight);
    if (i >= 0) _rooms[i] = updated;
    return updated;
  }
}