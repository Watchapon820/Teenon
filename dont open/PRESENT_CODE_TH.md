# สคริปต์พรีโค้ด Flutter แบบเข้าใจง่าย

พูดเปิดได้ว่า:

“โปรเจกต์ Teenon เป็นแอปจองโรงแรมที่พัฒนาด้วย Flutter และภาษา Dart โดยเวอร์ชันนี้ทำเฉพาะ Frontend ก่อน ยังไม่ได้เชื่อม Backend หรือ Database ข้อมูลในแอปจึงเป็น Dummy Data ค่ะ”

## 1) main.dart
```dart
void main() {
  runApp(const TeenonApp());
}
```
อธิบาย: `main()` เป็นจุดเริ่มต้นของแอป และ `runApp()` สั่งให้ Flutter แสดง Widget หลักชื่อ `TeenonApp`

## 2) app.dart
```dart
MaterialApp(
  theme: buildAppTheme(),
  home: const LoginScreen(),
)
```
อธิบาย: `MaterialApp` เป็นตัวครอบแอปทั้งหมด กำหนด Theme และกำหนดหน้าแรกเป็น Login

## 3) Widget คืออะไร
Flutter สร้างหน้าจอจาก Widget เช่น `Text`, `TextField`, `FilledButton`, `Card`, `ListView`

- `Text` แสดงข้อความ
- `TextField` รับข้อมูลผู้ใช้
- `FilledButton` สร้างปุ่ม
- `Card` สร้างกล่องข้อมูล
- `ListView` ทำให้เลื่อนหน้าจอได้

## 4) การเปลี่ยนหน้า
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const HomeScreen()),
);
```
อธิบาย: `Navigator.push` ใช้เปิดหน้าถัดไป เช่น Login ไป Home หรือโรงแรมไปหน้ารายละเอียด

## 5) StatefulWidget
หน้าที่ข้อมูลเปลี่ยนได้ เช่น Login, Search, Booking, Chat ใช้ `StatefulWidget`

```dart
setState(() {
  saved = !saved;
});
```
อธิบาย: `setState()` บอก Flutter ว่าข้อมูลเปลี่ยนแล้ว ให้สร้างหน้าจอส่วนนั้นใหม่ เช่น กดหัวใจ, เปลี่ยนจำนวนห้อง, เลือกคะแนนรีวิว

## 6) Dummy Data
ข้อมูลโรงแรมอยู่ใน `dummy_data.dart`
```dart
const hotels = <Hotel>[ ... ];
```
อธิบาย: ตอนนี้ยังไม่ดึงข้อมูลจาก Server จึงสร้างข้อมูลตัวอย่างไว้ในแอปก่อน ถ้าทำ Backend ภายหลังจึงเปลี่ยนส่วนนี้เป็น API ได้

## 7) Theme
สีและรูปแบบกลางอยู่ใน `app_theme.dart`
อธิบาย: แยก Theme ไว้ส่วนกลาง ทำให้เปลี่ยนสีปุ่ม Card และ Input ได้ทั้งแอปโดยไม่ต้องแก้ทีละหน้า

## 8) HotelCard
`HotelCard` เป็น Widget ที่สร้างไว้ใช้ซ้ำ
อธิบาย: แทนที่จะเขียนหน้าตาการ์ดโรงแรมใหม่ทุกครั้ง เราสร้าง Widget กลางแล้วส่งข้อมูลโรงแรมเข้าไป ทำให้โค้ดสั้นและแก้ง่าย

## 9) Flow
Login → Home → Hotel List → Hotel Detail → Booking → Payment → Booking Detail

นอกจากนี้มี Saved, Review, Chat, Settings และ Profile

## สรุปจำง่าย
- Dart = ภาษาที่ใช้เขียน
- Flutter = Framework สร้างแอป
- Widget = ส่วนประกอบหน้าจอ
- StatefulWidget = หน้าที่ข้อมูลเปลี่ยนได้
- setState = อัปเดตหน้าจอ
- Navigator = เปลี่ยนหน้า
- Dummy Data = ข้อมูลตัวอย่าง
- Backend / Database = ยังไม่ได้เชื่อม
