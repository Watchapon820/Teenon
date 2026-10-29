// ใส่ข้อมูลเริ่มต้น: npm run seed
//   - สร้างบัญชีแอดมิน admin@teenon.com ถ้ายังไม่มี ด้วยรหัสผ่านสุ่ม (บันทึกไว้ในไฟล์ ADMIN_PASSWORD.txt)
//   - npm run seed -- --reset-admin   สุ่มรหัสผ่านแอดมินใหม่
//   - SEED_ADMIN_PASSWORD=xxxx npm run seed -- --reset-admin   ตั้งรหัสผ่านแอดมินเอง
//   - SEED_DEMO=1 npm run seed   สร้างบัญชีทดลอง somchai@email.com / 123456 (ใช้ตอนพัฒนาเท่านั้น)
//   - เพิ่มโรงแรมตัวอย่างถ้าตาราง hotels ยังว่าง
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const db = require('./db');

const ADMIN_EMAIL = 'admin@teenon.com';
const hotels = [
  { name: 'Teenon Grand Bangkok', location: 'Bangkok', rating: 4.6, rooms: [['Deluxe', 1800], ['Suite', 3200]] },
  { name: 'Teenon Beach Phuket', location: 'Phuket', rating: 4.4, rooms: [['Sea View', 2400], ['Villa', 5200]] },
  { name: 'Teenon Mountain Chiang Mai', location: 'Chiang Mai', rating: 4.5, rooms: [['Standard', 1200], ['Family', 2100]] },
];

function randomPassword() {
  return crypto.randomBytes(9).toString('base64').replace(/[+/=]/g, 'x'); // 12 ตัวอักษร
}

async function upsertUser({ name, email, password, role, reset }) {
  const [rows] = await db.query('SELECT 1 FROM users WHERE email = ? LIMIT 1', [email]);
  const hash = await bcrypt.hash(password, 10);
  if (rows.length === 0) {
    await db.query('INSERT INTO users (name, email, password_hash, role) VALUES (?, ?, ?, ?)', [name, email, hash, role]);
    return 'created';
  }
  if (reset) {
    await db.query('UPDATE users SET password_hash = ?, role = ? WHERE email = ?', [hash, role, email]);
    return 'reset';
  }
  return 'exists';
}

(async () => {
  try {
    const resetAdmin = process.argv.includes('--reset-admin');
    const adminPassword = process.env.SEED_ADMIN_PASSWORD || randomPassword();
    const result = await upsertUser({ name: 'Admin', email: ADMIN_EMAIL, password: adminPassword, role: 'admin', reset: resetAdmin });
    if (result === 'exists') {
      console.log('แอดมินมีอยู่แล้ว (ไม่เปลี่ยนรหัสผ่าน; ใช้ --reset-admin ถ้าต้องการรีเซ็ต)');
    } else {
      const file = path.join(__dirname, 'ADMIN_PASSWORD.txt');
      fs.writeFileSync(file, `อีเมล: ${ADMIN_EMAIL}\nรหัสผ่าน: ${adminPassword}\n(เข้าสู่ระบบแล้วควรเปลี่ยนรหัสผ่าน และลบไฟล์นี้)\n`);
      console.log(`${result === 'created' ? 'สร้าง' : 'รีเซ็ตรหัสผ่าน'}แอดมินแล้ว — รหัสผ่านอยู่ในไฟล์ ADMIN_PASSWORD.txt`);
    }

    if (process.env.SEED_DEMO === '1') {
      const r = await upsertUser({ name: 'Somchai', email: 'somchai@email.com', password: '123456', role: 'user', reset: true });
      console.log('บัญชีทดลอง somchai@email.com:', r);
    }

    const [[{ n }]] = await db.query('SELECT COUNT(*) AS n FROM hotels');
    if (n === 0) {
      for (const h of hotels) {
        const [r] = await db.query('INSERT INTO hotels (name, location, description, rating) VALUES (?, ?, ?, ?)', [h.name, h.location, h.name, h.rating]);
        for (const [type, price] of h.rooms) {
          await db.query('INSERT INTO rooms (hotel_id, room_type, price_per_night) VALUES (?, ?, ?)', [r.insertId, type, price]);
        }
      }
      console.log('เพิ่มโรงแรมตัวอย่างแล้ว');
    }
    console.log('เสร็จสิ้น');
  } catch (e) {
    console.error('ผิดพลาด:', e.message || e.code);
    process.exitCode = 1;
  }
  process.exit();
})();
