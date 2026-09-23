# Teenon Flutter Frontend

แอปจองโรงแรม Teenon เวอร์ชัน Flutter สำหรับทำ **Frontend Demo** เท่านั้น ยังไม่เชื่อม Backend, Database, API หรือ Payment จริง

## หน้าที่มีในโปรเจกต์
- Login / Register
- Home + Search
- รายการโรงแรม + Filter
- รายละเอียดโรงแรม
- เลือกห้องและกรอกข้อมูลจอง
- Payment + QR Demo + แนบสลิป Demo
- รายการจอง / รายละเอียดการจอง / ยกเลิกการจอง
- Saved Hotels
- รีวิวและให้ดาว
- Chat Assistant แบบ Demo
- Settings
- Profile + Edit

## วิธีที่ง่ายที่สุด ถ้ามีโปรเจกต์ Flutter อยู่แล้ว
1. ปิดแอปที่กำลังรัน
2. Copy โฟลเดอร์ `lib` จากโปรเจกต์นี้ ไปแทน `lib` ของโปรเจกต์เดิม
3. Copy `pubspec.yaml` ไปแทนของเดิม
4. เปิด Terminal ใน VS Code แล้วรัน

```bash
flutter pub get
flutter run
```

โปรเจกต์นี้ใช้เฉพาะ Flutter SDK ไม่มี package เพิ่ม จึงติดตั้งง่าย

## ถ้าจะเปิดโฟลเดอร์นี้เป็นโปรเจกต์ใหม่บน Windows
ดับเบิลคลิก `SETUP_WINDOWS.bat` 1 ครั้ง ระบบจะใช้ `flutter create` เพื่อสร้างไฟล์ Android platform ให้ตรงกับ Flutter SDK ที่ติดตั้งอยู่ แล้วจึง `flutter pub get`

จากนั้นรัน `RUN_WINDOWS.bat` หรือใช้

```bash
flutter run
```

## โครงสร้างโค้ด
- `lib/main.dart` จุดเริ่มต้นโปรแกรม
- `lib/app.dart` ตั้งค่า MaterialApp และ Theme
- `lib/theme/app_theme.dart` สี ปุ่ม Input Card และ Theme กลาง
- `lib/models/hotel.dart` โครงสร้างข้อมูลโรงแรม
- `lib/data/dummy_data.dart` Dummy Data โรงแรม
- `lib/widgets/` Widget ที่ใช้ซ้ำ เช่น HotelCard และ Navigation
- `lib/screens/` หน้าจอทั้งหมด

## หมายเหตุ
ข้อมูลในแอปเป็น Dummy Data และการกด Login / Payment / Upload Slip / Review จะจำลองเฉพาะการทำงานของหน้าจอ ยังไม่มีการบันทึกจริง
