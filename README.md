# Teenon — แอปจองโรงแรม (Flutter + Node.js + MySQL)

## เริ่มใช้งาน
1. ติดตั้ง Node.js, MySQL, Flutter
2. สร้างฐานข้อมูล: `mysql -u root -p < schema.sql`
3. คัดลอก `.env.example` เป็น `.env` แล้วกรอกค่า (อย่างน้อย `DB_*` และ `JWT_SECRET` ที่สุ่มยาว ๆ ≥ 16 ตัวอักษร)
4. `npm install`
5. `npm run seed` — สร้างแอดมิน `admin@teenon.com` รหัสผ่านสุ่ม (อยู่ในไฟล์ `ADMIN_PASSWORD.txt` ให้เข้าสู่ระบบแล้วเปลี่ยน/ลบไฟล์)
   - `npm run seed -- --reset-admin` สุ่มรหัสแอดมินใหม่ · `SEED_DEMO=1 npm run seed` สร้างบัญชีทดลอง (ตอนพัฒนาเท่านั้น)
6. `npm start` (บน Windows: ดับเบิลคลิก `start_server.bat`)
7. `flutter run` — ชี้เซิร์ฟเวอร์อื่นด้วย `--dart-define=API_BASE_URL=https://โดเมน/api`

## ค่าใน .env ที่ควรตั้งก่อนเปิดใช้จริง
| ตัวแปร | ใช้ทำอะไร |
|---|---|
| `PROMPTPAY_ID` | เบอร์มือถือ/เลขบัตร 13 หลัก — แอปสร้าง PromptPay QR พร้อมยอดให้ลูกค้า |
| `BANK_NAME` `BANK_ACCOUNT_NO` `BANK_ACCOUNT_NAME` | บัญชีสำหรับโอนเงิน |
| `CONTACT_PHONE` `CONTACT_LINE` `CONTACT_EMAIL` `CONTACT_HOURS` | หน้า "ติดต่อเรา" |
| `UNPAID_EXPIRE_HOURS` | การจองที่ไม่ส่งสลิปเกินเวลานี้ถูกยกเลิกอัตโนมัติ (ค่าเริ่มต้น 24) |
| `TRUST_PROXY` | ตั้งเป็น `1` เมื่อรันหลัง reverse proxy ที่ทำ HTTPS |

## ขั้นตอนการจอง
ลูกค้าจอง → สถานะ **รอชำระเงิน** → สแกน QR/โอน แล้วแนบสลิป → **รอตรวจสลิป** → แอดมินกด **ยืนยัน** (ลูกค้าได้แจ้งเตือน) · แอดมินปฏิเสธ/ยกเลิกพร้อมเหตุผลได้ · ไม่ชำระใน 24 ชม. ระบบยกเลิกให้เอง
ห้องว่างตรวจรายคืนจาก "จำนวนห้องที่มี" ของห้องแต่ละประเภท (ตั้งในหน้าแอดมิน > ห้องพัก)

## ขึ้นระบบจริง (HTTPS)
เซิร์ฟเวอร์รันแบบ HTTP ธรรมดา ให้วางหลัง reverse proxy ที่ทำ HTTPS เสมอ เช่น Caddy (ขอใบรับรองให้อัตโนมัติ):
```
api.example.com {
    reverse_proxy localhost:5000
}
```
แล้วตั้ง `TRUST_PROXY=1` และสร้างแอปด้วย `--dart-define=API_BASE_URL=https://api.example.com/api`
Android: ถ้าใช้ HTTPS ทั้งหมด ให้ลบ `android:usesCleartextTraffic="true"` ออกจาก `AndroidManifest.xml`

## เช็กลิสต์ความปลอดภัยก่อนเปิดใช้จริง
- เปลี่ยนรหัสผ่านฐานข้อมูลและ `JWT_SECRET` ถ้าเคยอยู่ใน git/แชร์ออกไป (`.env` ห้าม commit)
- ลบบัญชีทดลอง (`somchai@email.com`) และเปลี่ยนรหัสผ่านแอดมิน
- ไฟล์สลิปเก็บใน `private_uploads/` (ไม่เปิดสาธารณะ) รูปโรงแรมเก็บใน `uploads/`
- การรีเซ็ตรหัสผ่านในแอป: บัญชีแอดมินรีเซ็ตเองไม่ได้ และบัญชีที่มีเบอร์โทรต้องกรอกเบอร์ให้ตรง (ยังไม่มีการส่งอีเมลยืนยัน)
