const express = require('express');
const cors = require('cors');
require('dotenv').config();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const db = require('./db');
const { notify, addDays, todayStr, sendMail, peakBookedByRoom, stayRange, activeDealsByHotel, discounted, dealView } = require('./helpers');
const { signToken, authenticate, requireAdmin } = require('./auth');

const app = express();
const PORT = process.env.PORT || 5000;

// หลัง reverse proxy (เช่น Caddy/nginx ที่ทำ HTTPS) ให้ตั้ง TRUST_PROXY=1 ใน .env
if (process.env.TRUST_PROXY) app.set('trust proxy', 1);
app.disable('x-powered-by');
const allowedOrigins = new Set((process.env.CORS_ORIGINS || '').split(',').map(origin => origin.trim()).filter(Boolean));
const corsOptions = {
  origin(origin, callback) {
    if (!origin || allowedOrigins.has(origin)) return callback(null, true);
    if (process.env.NODE_ENV !== 'production') {
      try {
        const { hostname, protocol } = new URL(origin);
        if ((hostname === 'localhost' || hostname === '127.0.0.1') && (protocol === 'http:' || protocol === 'https:')) {
          return callback(null, true);
        }
      } catch {
        return callback(null, false);
      }
    }
    return callback(null, false);
  },
};
app.use((req, res, next) => {
  res.set({ 'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY', 'Referrer-Policy': 'no-referrer' });
  if (req.secure) res.set('Strict-Transport-Security', 'max-age=15552000');
  next();
});
// log คำขอ API แบบย่อ (เวลา IP เส้นทาง สถานะ) ไว้ไล่ปัญหา — ไม่เก็บ body/header; ข้ามคำขอ poll ที่สำเร็จ (แชท/สถิติ/ping) กัน log ท่วม
app.use((req, res, next) => {
  if (!req.path.startsWith('/api/')) return next();
  const started = Date.now();
  res.on('finish', () => {
    const quiet = res.statusCode < 400 && /^\/api\/(chat|admin\/chats|admin\/stats|notifications|ping)/.test(req.path);
    if (!quiet) console.log(`${new Date().toISOString()} ${req.ip} ${req.method} ${req.path} ${res.statusCode} ${Date.now() - started}ms`);
  });
  next();
});
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));

// ===== รูปภาพ: เก็บไฟล์ในโฟลเดอร์ uploads/ แล้วให้เข้าถึงผ่าน /uploads/<ชื่อไฟล์> =====
const fs = require('fs');
const path = require('path');
const UPLOAD_DIR = path.join(__dirname, 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });
app.use('/uploads', express.static(UPLOAD_DIR));

// ให้คอลัมน์ bookings.status รองรับสถานะ 'pending' (รอยืนยัน) ถ้ายังเป็น ENUM ที่ไม่มีค่านี้
void (async () => {
  try {
    const [cols] = await db.query("SHOW COLUMNS FROM bookings LIKE 'status'");
    const type = cols[0] && cols[0].Type;
    if (type && /^enum\(/i.test(type) && !type.includes("'pending'")) {
      await db.query("ALTER TABLE bookings MODIFY status ENUM('pending','confirmed','cancelled','completed') NOT NULL DEFAULT 'pending'");
    }
  } catch (e) {
    console.error("ปรับคอลัมน์ bookings.status ไม่สำเร็จ:", e.message);
  }
})();

// เพิ่มคอลัมน์ image_url ให้ตาราง hotels / rooms ถ้ายังไม่มี
void (async () => {
  for (const table of ['hotels', 'rooms']) {
    try {
      const [cols] = await db.query(`SHOW COLUMNS FROM ${table} LIKE 'image_url'`);
      if (cols.length === 0) await db.query(`ALTER TABLE ${table} ADD COLUMN image_url VARCHAR(255) NULL`);
    } catch (e) {
      console.error(`ตรวจ/เพิ่มคอลัมน์ image_url ของ ${table} ไม่สำเร็จ:`, e.message);
    }
  }
})();

// จำกัดจำนวนครั้งที่ล็อกอิน/สมัครสมาชิกต่อ IP (กัน brute force)
const attempts = new Map();
function rateLimit(max, windowMs) {
  return (req, res, next) => {
    const now = Date.now();
    const rec = attempts.get(req.ip);
    if (!rec || now > rec.reset) {
      attempts.set(req.ip, { count: 1, reset: now + windowMs });
      return next();
    }
    if (++rec.count > max) {
      return res.status(429).json({ success: false, message: 'ลองบ่อยเกินไป กรุณารอสักครู่' });
    }
    next();
  };
}
const authLimiter = rateLimit(20, 15 * 60 * 1000);

// พิมพ์รายละเอียด error ลง Terminal เพื่อช่วยหาสาเหตุ แต่ส่งให้ผู้ใช้เฉพาะข้อความกลาง ๆ
// (ไม่เปิดเผยรายละเอียดฐานข้อมูล/SQL ให้ฝั่ง client)
const DB_DOWN_CODES = ['ECONNREFUSED', 'PROTOCOL_CONNECTION_LOST', 'ER_ACCESS_DENIED_ERROR', 'ER_BAD_DB_ERROR', 'ETIMEDOUT'];
function errText(error) {
  console.error('❌', error);
  const code = (error && error.code) || (error && error.errors && error.errors[0] && error.errors[0].code);
  if (DB_DOWN_CODES.includes(code)) return 'ระบบฐานข้อมูลไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง';
  return 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่อีกครั้ง';
}


// ===== ระบบสมาชิก =====
// ตรวจชื่อคอลัมน์จริงในตาราง users (ตารางเดิมอาจตั้งชื่อต่างจากที่คาด) แล้วจำไว้
let userColsCache = null;
async function userCols() {
  if (userColsCache) return userColsCache;
  const [cols] = await db.query('SHOW COLUMNS FROM users');
  const have = cols.map((c) => c.Field);
  const pick = (list) => list.find((n) => have.includes(n)) || null;
  const c = {
    id: pick(['user_id', 'id']),
    name: pick(['name', 'full_name', 'fullname', 'username', 'user_name', 'display_name']),
    email: pick(['email', 'user_email']),
    phone: pick(['phone', 'phone_number', 'tel', 'mobile']),
    pass: pick(['password_hash', 'password', 'passwd']),
    role: pick(['role', 'user_role']),
  };
  const missing = ['id', 'email', 'pass', 'role'].filter((k) => !c[k]);
  if (missing.length) {
    throw new Error('ตาราง users ไม่มีคอลัมน์: ' + missing.join(', ') + ' (ดู migration_users.sql) คอลัมน์ที่มี: ' + have.join(', '));
  }
  userColsCache = c;
  return c;
}
// สมัครสมาชิก (role = user เสมอ; แอดมินต้องตั้งในฐานข้อมูลเท่านั้น)
app.post('/api/register', authLimiter, async (req, res) => {
  const name = String(req.body?.name || '').trim();
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');
  const phone = String(req.body?.phone || '').trim();
  if (!name || !email || password.length < 6) {
    return res.status(400).json({ success: false, message: 'กรอกชื่อ อีเมล และรหัสผ่านอย่างน้อย 6 ตัวอักษร' });
  }
  try {
    const c = await userCols();
    const [dup] = await db.query(`SELECT 1 FROM users WHERE ${c.email} = ? LIMIT 1`, [email]);
    if (dup.length > 0) return res.status(409).json({ success: false, message: 'อีเมลนี้ถูกใช้แล้ว' });
    const hash = await bcrypt.hash(password, 10);
    const cols = [c.email, c.pass, c.role];
    const vals = [email, hash, 'user'];
    if (c.name) { cols.push(c.name); vals.push(name); }
    if (c.phone) { cols.push(c.phone); vals.push(phone); }
    const [r] = await db.query(
      `INSERT INTO users (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`,
      vals
    );
    const user = { user_id: r.insertId, name, email, phone, role: 'user' };
    res.status(201).json({ success: true, token: signToken(user), user: publicUser(user) });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// เข้าสู่ระบบ: คืน token + role เพื่อให้แอปเลือกหน้า (user → Home, admin → หน้าแอดมิน)
app.post('/api/login', authLimiter, async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');
  try {
    const c = await userCols();
    const [rows] = await db.query(`SELECT * FROM users WHERE ${c.email} = ? LIMIT 1`, [email]);
    const row = rows[0];
    const ok = row && row[c.pass] && (await bcrypt.compare(password, String(row[c.pass])));
    if (!ok) return res.status(401).json({ success: false, message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' });
    const user = normalizeUser(row, c);
    res.json({ success: true, token: signToken(user), user: publicUser(user) });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// ===== ลืมรหัสผ่าน =====
// ขั้น 1: ขอรหัสยืนยัน 6 หลัก — ส่งไปที่อีเมลของบัญชี (ตอบเหมือนกันทุกกรณี ไม่บอกว่ามีอีเมลนี้หรือไม่)
// ขั้น 2: กรอกรหัสยืนยัน + รหัสผ่านใหม่ (รหัสใช้ได้ครั้งเดียว ภายใน 15 นาที ผิดได้ไม่เกิน 5 ครั้ง)
// บัญชีแอดมินรีเซ็ตด้วยวิธีนี้ไม่ได้ (ใช้ npm run seed -- --reset-admin)
const RESET_CODE_MINUTES = 15;
const RESET_MAX_TRIES = 5;

db.query(`
  CREATE TABLE IF NOT EXISTS password_resets (
    email VARCHAR(150) NOT NULL PRIMARY KEY,
    code_hash VARCHAR(100) NOT NULL,
    expires_at DATETIME NOT NULL,
    attempts INT NOT NULL DEFAULT 0
  )
`).catch((e) => console.error('สร้างตาราง password_resets ไม่สำเร็จ:', e.message));

async function findUserForReset(email) {
  const c = await userCols();
  const [rows] = await db.query(`SELECT * FROM users WHERE ${c.email} = ? LIMIT 1`, [email]);
  const row = rows[0];
  if (!row || row[c.role] === 'admin') return null;
  return { id: row[c.id], email: row[c.email], c };
}

const codeSent = { success: true, message: 'ถ้าอีเมลนี้มีอยู่ในระบบ เราได้ส่งรหัสยืนยัน 6 หลักไปแล้ว กรุณาตรวจสอบอีเมล' };
const badCode = { success: false, message: 'รหัสยืนยันไม่ถูกต้องหรือหมดอายุ กรุณาขอรหัสใหม่' };

app.post('/api/forgot-password', authLimiter, async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  if (!email) return res.status(400).json({ success: false, message: 'กรอกอีเมล' });
  try {
    const u = await findUserForReset(email);
    if (!u) return res.json(codeSent);
    const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
    await db.query(
      `REPLACE INTO password_resets (email, code_hash, expires_at, attempts)
       VALUES (?, ?, NOW() + INTERVAL ${RESET_CODE_MINUTES} MINUTE, 0)`,
      [u.email, await bcrypt.hash(code, 10)]
    );
    await sendMail(
      u.email,
      'รหัสยืนยันสำหรับตั้งรหัสผ่านใหม่ - Teenon',
      `รหัสยืนยันของคุณคือ ${code}\nรหัสนี้ใช้ได้ภายใน ${RESET_CODE_MINUTES} นาที\nถ้าคุณไม่ได้ขอเปลี่ยนรหัสผ่าน ไม่ต้องทำอะไร`
    );
    res.json(codeSent);
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

app.post('/api/reset-password', authLimiter, async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const code = String(req.body?.code || '').trim();
  const password = String(req.body?.password || '');
  if (!email || !/^\d{6}$/.test(code) || password.length < 6) {
    return res.status(400).json({ success: false, message: 'กรอกอีเมล รหัสยืนยัน 6 หลัก และรหัสผ่านใหม่อย่างน้อย 6 ตัวอักษร' });
  }
  try {
    const u = await findUserForReset(email);
    if (!u) return res.status(400).json(badCode);
    const [rows] = await db.query(
      'SELECT code_hash, attempts, expires_at > NOW() AS valid FROM password_resets WHERE email = ?',
      [u.email]
    );
    const r = rows[0];
    if (!r || !Number(r.valid) || r.attempts >= RESET_MAX_TRIES) return res.status(400).json(badCode);
    if (!(await bcrypt.compare(code, r.code_hash))) {
      await db.query('UPDATE password_resets SET attempts = attempts + 1 WHERE email = ?', [u.email]);
      return res.status(400).json(badCode);
    }
    await db.query(`UPDATE users SET ${u.c.pass} = ? WHERE ${u.c.id} = ?`, [await bcrypt.hash(password, 10), u.id]);
    await db.query('DELETE FROM password_resets WHERE email = ?', [u.email]);
    res.json({ success: true, message: 'ตั้งรหัสผ่านใหม่เรียบร้อยแล้ว กรุณาเข้าสู่ระบบ' });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

app.get('/api/me', authenticate, async (req, res) => {
  try {
    const c = await userCols();
    const [rows] = await db.query(`SELECT * FROM users WHERE ${c.id} = ? LIMIT 1`, [req.user.id]);
    if (rows.length === 0) return res.status(404).json({ success: false, message: 'ไม่พบผู้ใช้' });
    res.json({ success: true, user: publicUser(normalizeUser(rows[0], c)) });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// แปลงแถวจากตาราง users (ชื่อคอลัมน์อะไรก็ได้) เป็นรูปแบบกลาง
function normalizeUser(row, c) {
  return {
    user_id: row[c.id],
    name: c.name ? row[c.name] : '',
    email: row[c.email],
    phone: c.phone ? row[c.phone] : '',
    role: row[c.role] || 'user',
    avatar: row.avatar_url || '',
  };
}

function publicUser(u) {
  return { id: u.user_id, name: u.name, email: u.email, phone: u.phone || '', role: u.role || 'user', avatar: u.avatar || '' };
}

// แนบดีลที่ใช้ได้ตอนนี้ + ราคาเริ่มต้นหลังลด ให้รายการโรงแรม
async function attachDeals(hotels) {
  const deals = await activeDealsByHotel(db);
  return hotels.map((h) => {
    const d = deals.get(h.hotel_id);
    return {
      ...h,
      deal: d ? dealView(d) : null,
      deal_price: d && h.starting_price != null ? discounted(h.starting_price, d.discount_percent) : null,
    };
  });
}

// ห้องว่างรวมของแต่ละโรงแรม { hotel_id: { total, free } } (ค่าเริ่มต้น = คืนนี้; ส่ง ?checkIn=&checkOut= เพื่อดูช่วงอื่น)
async function hotelAvailability(query) {
  const { from, to } = stayRange(query);
  const [roomRows] = await db.query('SELECT room_id, hotel_id, quantity FROM rooms');
  const peaks = await peakBookedByRoom(db, from, to);
  const avail = {};
  for (const r of roomRows) {
    const a = (avail[r.hotel_id] = avail[r.hotel_id] || { total: 0, free: 0 });
    const qty = Number(r.quantity) || 0;
    a.total += qty;
    a.free += Math.max(0, qty - (peaks.get(r.room_id) || 0));
  }
  return avail;
}

// 1. GET: ดึงรายชื่อโรงแรมทั้งหมด (ราคาเริ่มต้นจากตาราง rooms, คะแนนเฉลี่ยจากรีวิวจริงถ้ามี, แท็ก)
app.get('/api/hotels', async (req, res) => {
  try {
    const sql = `
      SELECT h.*, MIN(r.price_per_night) AS starting_price,
             COALESCE((SELECT ROUND(AVG(rv.rating), 1) FROM reviews rv WHERE rv.hotel_id = h.hotel_id), h.rating) AS rating,
             (SELECT COUNT(*) FROM reviews rv WHERE rv.hotel_id = h.hotel_id) AS review_count
      FROM hotels h
      LEFT JOIN rooms r ON h.hotel_id = r.hotel_id
      GROUP BY h.hotel_id
    `;
    const [hotels] = await db.query(sql);
    const [tags] = await db.query('SELECT hotel_id, tag_name FROM hotel_tags');
    const byHotel = {};
    tags.forEach((t) => (byHotel[t.hotel_id] = byHotel[t.hotel_id] || []).push(t.tag_name));

    const avail = await hotelAvailability(req.query);
    res.json({
      success: true,
      data: (await attachDeals(hotels)).map((h) => ({
        ...h,
        tags: byHotel[h.hotel_id] || [],
        rooms_total: (avail[h.hotel_id] || {}).total || 0,
        rooms_available: (avail[h.hotel_id] || {}).free || 0,
      })),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// ===== โรงแรมที่บันทึกไว้ (ดาว) ของผู้ใช้แต่ละคน =====
db.query(`
  CREATE TABLE IF NOT EXISTS saved_hotels (
    user_id INT NOT NULL,
    hotel_id INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, hotel_id)
  )
`).catch((e) => console.error('สร้างตาราง saved_hotels ไม่สำเร็จ:', e.message));

app.get('/api/saved', authenticate, async (req, res) => {
  try {
    const [hotels] = await db.query(
      `SELECT h.*, MIN(r.price_per_night) AS starting_price
       FROM saved_hotels s
       JOIN hotels h ON h.hotel_id = s.hotel_id
       LEFT JOIN rooms r ON r.hotel_id = h.hotel_id
       WHERE s.user_id = ?
       GROUP BY h.hotel_id, s.created_at
       ORDER BY s.created_at DESC`,
      [req.user.id]
    );
    const avail = await hotelAvailability(req.query);
    res.json({
      success: true,
      data: (await attachDeals(hotels)).map((h) => ({
        ...h,
        rooms_total: (avail[h.hotel_id] || {}).total || 0,
        rooms_available: (avail[h.hotel_id] || {}).free || 0,
      })),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

app.put('/api/saved/:hotelId', authenticate, async (req, res) => {
  try {
    const [h] = await db.query('SELECT 1 FROM hotels WHERE hotel_id = ?', [req.params.hotelId]);
    if (h.length === 0) return res.status(404).json({ success: false, message: 'ไม่พบโรงแรมนี้' });
    await db.query('INSERT IGNORE INTO saved_hotels (user_id, hotel_id) VALUES (?, ?)', [req.user.id, req.params.hotelId]);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

app.delete('/api/saved/:hotelId', authenticate, async (req, res) => {
  try {
    await db.query('DELETE FROM saved_hotels WHERE user_id = ? AND hotel_id = ?', [req.user.id, req.params.hotelId]);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// 1.5 POST: เพิ่มข้อมูลโรงแรมใหม่ (ปรับคอลัมน์ตามตาราง hotels ใน ERD)
app.post('/api/hotels', authenticate, requireAdmin, async (req, res) => {
  const {
    name,
    location,
    description,
    rating,
    check_in_time,
    check_out_time,
    has_pool,
    has_breakfast,
    has_wifi,
    image_url,
  } = req.body;

  if (!String(name || '').trim()) {
    return res.status(400).json({ success: false, message: 'ต้องระบุชื่อโรงแรม' });
  }

  try {
    const sql = `
      INSERT INTO hotels 
      (name, location, description, rating, check_in_time, check_out_time, has_pool, has_breakfast, has_wifi, image_url)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const [result] = await db.query(sql, [
      name,
      location || '',
      description || '',
      rating || 0.0,
      check_in_time || '14:00:00',
      check_out_time || '12:00:00',
      has_pool !== undefined ? has_pool : 1,
      has_breakfast !== undefined ? has_breakfast : 1,
      has_wifi !== undefined ? has_wifi : 1,
      image_url || null,
    ]);

    res.status(201).json({
      success: true,
      message: 'เพิ่มข้อมูลโรงแรมสำเร็จ',
      hotelId: result.insertId,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// 2. GET: ดึงข้อมูลรายละเอียดโรงแรม พร้อมประเภทห้องพัก แท็ก แกลเลอรีรูป และคะแนนรีวิว
app.get('/api/hotels/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const [hotel] = await db.query(
      `SELECT h.*,
              COALESCE((SELECT ROUND(AVG(rv.rating), 1) FROM reviews rv WHERE rv.hotel_id = h.hotel_id), h.rating) AS rating,
              (SELECT COUNT(*) FROM reviews rv WHERE rv.hotel_id = h.hotel_id) AS review_count
       FROM hotels h WHERE h.hotel_id = ?`,
      [id]
    );

    if (hotel.length === 0) {
      return res.status(404).json({ success: false, message: 'Hotel not found' });
    }

    const [rooms] = await db.query('SELECT * FROM rooms WHERE hotel_id = ?', [id]);
    const [tags] = await db.query('SELECT tag_name FROM hotel_tags WHERE hotel_id = ?', [id]);
    const [images] = await db.query('SELECT image_url FROM hotel_images WHERE hotel_id = ? ORDER BY id', [id]);

    // จำนวนห้องว่างของแต่ละประเภท (ค่าเริ่มต้น = คืนนี้; ส่ง ?checkIn=&checkOut= เพื่อดูช่วงอื่น)
    const { from, to } = stayRange(req.query);
    const peaks = await peakBookedByRoom(db, from, to, rooms.map((r) => r.room_id));
    const deal = (await activeDealsByHotel(db, hotel[0].hotel_id)).get(hotel[0].hotel_id);
    const roomsWithAvail = rooms.map((r) => ({
      ...r,
      rooms_available: Math.max(0, (Number(r.quantity) || 0) - (peaks.get(r.room_id) || 0)),
      deal_price: deal ? discounted(r.price_per_night, deal.discount_percent) : null,
    }));

    res.json({
      success: true,
      data: {
        ...hotel[0],
        tags: tags.map((t) => t.tag_name),
        images: images.map((i) => i.image_url),
        rooms: roomsWithAvail,
        deal: deal ? dealView(deal) : null,
        rooms_total: roomsWithAvail.reduce((s, r) => s + (Number(r.quantity) || 0), 0),
        rooms_available: roomsWithAvail.reduce((s, r) => s + r.rooms_available, 0),
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // ไม่มี 0/O, 1/I
function newBookingCode() {
  let s = 'TN-';
  for (let i = 0; i < 8; i++) s += CODE_ALPHABET[crypto.randomInt(CODE_ALPHABET.length)];
  return s;
}

// 3. POST: บันทึกข้อมูลการจองใหม่ (เริ่มที่สถานะ "รอยืนยัน")
//    - ยอดรวมคำนวณที่ server จากราคาห้องจริง
//    - ตรวจจำนวนห้องว่างรายคืนใน transaction เดียว (ล็อกแถวห้องกันจองซ้อนกัน)
app.post('/api/bookings', authenticate, async (req, res) => {
  // userId มาจาก token เสมอ (ไม่เชื่อค่าจาก body)
  const userId = req.user.id;
  const { hotelId, roomId, guestName, guestEmail, guestPhone, checkIn, checkOut, specialRequest } = req.body;
  const nRooms = Math.max(1, Number.parseInt(req.body.numRooms, 10) || 1);
  const nGuests = Math.max(1, Number.parseInt(req.body.numGuests, 10) || 1);
  const ciStr = String(checkIn || '').slice(0, 10);
  const coStr = String(checkOut || '').slice(0, 10);
  const ci = new Date(ciStr + 'T00:00:00Z');
  const co = new Date(coStr + 'T00:00:00Z');
  if (!hotelId || !roomId || Number.isNaN(ci.getTime()) || Number.isNaN(co.getTime()) || co <= ci) {
    return res.status(400).json({ success: false, message: 'ข้อมูลการจองไม่ถูกต้อง (ตรวจโรงแรม ห้อง และวันที่เข้าพัก/ออก)' });
  }
  if (ciStr < todayStr()) {
    return res.status(400).json({ success: false, message: 'ไม่สามารถจองย้อนหลังได้' });
  }
  const nights = Math.round((co - ci) / 86400000);
  if (nights > 60) {
    return res.status(400).json({ success: false, message: 'จองได้ครั้งละไม่เกิน 60 คืน' });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [roomRows] = await conn.query(
      'SELECT price_per_night, quantity, max_guests FROM rooms WHERE room_id = ? AND hotel_id = ? FOR UPDATE',
      [roomId, hotelId]
    );
    if (roomRows.length === 0) {
      await conn.rollback();
      return res.status(400).json({ success: false, message: 'ไม่พบห้องนี้ในโรงแรมที่เลือก' });
    }
    const room = roomRows[0];
    if (room.max_guests && nGuests > room.max_guests * nRooms) {
      await conn.rollback();
      return res.status(400).json({ success: false, message: `ห้องนี้พักได้สูงสุด ${room.max_guests} คนต่อห้อง` });
    }

    // จำนวนห้องที่ถูกจองในแต่ละคืนของช่วงที่เลือก (เฉพาะรายการที่แอดมิน "ยืนยันแล้ว" — รอยืนยันยังไม่ลดห้องว่าง
    // ห้องจะถูกตัดจริงตอนแอดมินกดยืนยัน และตอนนั้นระบบตรวจซ้ำว่าห้องยังพอ)
    if (room.quantity != null) {
      const [overlap] = await conn.query(
        "SELECT check_in_date, check_out_date, num_rooms FROM bookings WHERE room_id = ? AND status IN ('confirmed','completed') AND check_in_date < ? AND check_out_date > ?",
        [roomId, coStr, ciStr]
      );
      let peak = 0;
      for (let d = ciStr; d < coStr; d = addDays(d, 1)) {
        const used = overlap
          .filter((b) => String(b.check_in_date).slice(0, 10) <= d && String(b.check_out_date).slice(0, 10) > d)
          .reduce((sum, b) => sum + (Number(b.num_rooms) || 1), 0);
        peak = Math.max(peak, used);
      }
      if (peak + nRooms > room.quantity) {
        await conn.rollback();
        const left = Math.max(0, room.quantity - peak);
        return res.status(409).json({
          success: false,
          message: left === 0 ? 'ห้องประเภทนี้เต็มในช่วงวันที่เลือก ลองเปลี่ยนวันที่หรือเลือกห้องอื่น' : `ห้องประเภทนี้เหลือเพียง ${left} ห้องในช่วงวันที่เลือก`,
        });
      }
    }

    // สุ่มรหัสจอง TN-XXXXXXXX (8 ตัว จากตัวอักษร/ตัวเลขที่ไม่สับสนกัน ~1 ล้านล้านแบบ) จนกว่าจะไม่ซ้ำ
    let bookingCode = null;
    for (let i = 0; i < 10 && !bookingCode; i++) {
      const candidate = newBookingCode();
      const [dup] = await conn.query('SELECT 1 FROM bookings WHERE booking_code = ? LIMIT 1', [candidate]);
      if (dup.length === 0) bookingCode = candidate;
    }
    if (!bookingCode) {
      await conn.rollback();
      return res.status(500).json({ success: false, message: 'สร้างรหัสการจองไม่สำเร็จ ลองใหม่อีกครั้ง' });
    }

    // ราคาคิดที่ server เสมอ: ถ้าโรงแรมมีดีลที่ใช้ได้ตอนจอง หักส่วนลด % จากราคาต่อคืน
    const deal = (await activeDealsByHotel(conn, Number(hotelId))).get(Number(hotelId));
    const unitPrice = deal ? discounted(room.price_per_night, deal.discount_percent) : Number(room.price_per_night);
    const originalAmount = Math.round(Number(room.price_per_night) * nights * nRooms * 100) / 100;
    const totalAmount = Math.round(unitPrice * nights * nRooms * 100) / 100;
    const discountAmount = Math.round((originalAmount - totalAmount) * 100) / 100;
    const [result] = await conn.query(
      `INSERT INTO bookings
       (booking_code, user_id, hotel_id, room_id, guest_name, guest_email, guest_phone, check_in_date, check_out_date, num_rooms, num_guests, special_request, total_amount, deal_id, discount_amount, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
      [bookingCode, userId, hotelId, roomId, guestName || '', guestEmail || '', guestPhone || '', ciStr, coStr, nRooms, nGuests, specialRequest || '', totalAmount, deal ? deal.deal_id : null, discountAmount]
    );
    await conn.commit();

    await notify(userId, 'ได้รับการจองแล้ว', `การจอง ${bookingCode} รอชำระเงินและให้เจ้าหน้าที่ยืนยัน`);
    res.status(201).json({
      success: true,
      message: 'Booking created successfully',
      bookingId: result.insertId,
      bookingCode: bookingCode,
      totalAmount,
      originalAmount,
      discountAmount,
      dealTitle: deal ? deal.title : null,
      discountPercent: deal ? Number(deal.discount_percent) : 0,
    });
  } catch (error) {
    await conn.rollback().catch(() => {});
    res.status(500).json({ success: false, message: errText(error) });
  } finally {
    conn.release();
  }
});

// นโยบายยกเลิกสำหรับลูกค้า (แอดมินยกเลิกได้เสมอ): คืนเหตุผลที่ยกเลิกไม่ได้ หรือ null ถ้ายกเลิกได้
//  - ยกเลิกได้เฉพาะรายการที่รอยืนยัน/ยืนยันแล้ว และยังไม่เลยวันเช็คอิน
//  - รายการที่ยังไม่ส่งสลิป (ยังไม่ได้จ่ายเงิน) ยกเลิกได้จนถึงวันเช็คอิน
//  - รายการที่จ่ายแล้วต้องยกเลิกก่อนเช็คอินอย่างน้อย free_cancel_days วัน (0 = ได้ถึงวันเช็คอิน)
function cancelBlock(b) {
  if (b.status === 'cancelled') return 'รายการจองนี้ถูกยกเลิกไปแล้ว';
  if (b.status !== 'pending' && b.status !== 'confirmed') return 'รายการจองนี้ยกเลิกไม่ได้แล้ว';
  const checkIn = String(b.check_in_date).slice(0, 10);
  const today = todayStr();
  if (today > checkIn) return 'เลยวันเช็คอินแล้ว ยกเลิกไม่ได้';
  const paid = b.status === 'confirmed' || Boolean(b.slip_file);
  const days = Math.max(0, Number.parseInt(b.free_cancel_days, 10) || 0);
  if (paid && days > 0 && today > addDays(checkIn, -days)) {
    return `เลยช่วงยกเลิกฟรีแล้ว (ต้องยกเลิกก่อนเช็คอิน ${days} วัน) กรุณาติดต่อเจ้าหน้าที่`;
  }
  return null;
}

// 4. GET: ดึงรายการจองของผู้ใช้ (ล่าสุดอยู่บนสุด) เช่น /api/bookings?userId=1
app.get('/api/bookings', authenticate, async (req, res) => {
  const userId = req.user.id; // เห็นเฉพาะของตัวเอง
  try {
    let sql = `
      SELECT b.*, h.name AS hotel_name, h.location AS hotel_location, h.image_url AS hotel_image, h.free_cancel_days,
             EXISTS(SELECT 1 FROM reviews rv WHERE rv.booking_id = b.booking_id) AS has_review
      FROM bookings b
      LEFT JOIN hotels h ON h.hotel_id = b.hotel_id
    `;
    // ไม่แสดงรายการที่ยกเลิกแล้วในหน้า My bookings (ข้อมูลอยู่ในตาราง cancellations)
    const conditions = ["(b.status IS NULL OR b.status <> 'cancelled')"];
    const params = [];
    if (userId) {
      conditions.push('b.user_id = ?');
      params.push(userId);
    }
    sql += ' WHERE ' + conditions.join(' AND ');
    const [rows] = await db.query(sql, params);

    // ดึงชื่อห้องแยก (ไม่ผูกกับชื่อคอลัมน์ใน rooms)
    const roomIds = [...new Set(rows.map((r) => r.room_id).filter((v) => v != null))];
    const roomNames = {};
    if (roomIds.length > 0) {
      const [rooms] = await db.query('SELECT * FROM rooms WHERE room_id IN (?)', [roomIds]);
      rooms.forEach((r) => {
        roomNames[r.room_id] = r.room_type || r.type_name || r.room_name || r.name || null;
      });
    }

    const data = rows.map((r) => ({
      ...r,
      slip_file: undefined,
      has_slip: Boolean(r.slip_file),
      cancel_block: cancelBlock(r),
      room_label: roomNames[r.room_id] || 'ห้องพัก',
    }));

    // เรียงล่าสุดก่อน (ตาม booking_id ถ้าไม่มีใช้ id)
    const key = (r) => Number(r.booking_id ?? r.id ?? 0);
    data.sort((a, b) => key(b) - key(a));

    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// 5. PUT: ยกเลิกการจอง
//    - เปลี่ยน status ในตาราง bookings จาก confirmed เป็น cancelled
//    - บันทึก booking_id, เหตุผล, รายละเอียดเพิ่มเติม และเวลาที่ยกเลิกลงตาราง cancellations
//    ทำใน transaction เดียวกัน ถ้าขั้นใดพลาดจะย้อนกลับทั้งหมด
app.put('/api/bookings/:code/cancel', authenticate, async (req, res) => {
  const { code } = req.params;
  // เหตุผลและรายละเอียดเพิ่มเติมจากหน้ายกเลิกการจอง (reason ในตารางเป็น NOT NULL, ยาวไม่เกิน 100 ตัวอักษร)
  const reason = String(req.body?.reason || '').trim().slice(0, 100) || 'ไม่ระบุ';
  const additionalDetails = String(req.body?.additionalDetails || '').trim() || null;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [rows] = await conn.query(
      `SELECT b.booking_id, b.status, b.user_id, b.check_in_date, b.slip_file, h.free_cancel_days
       FROM bookings b LEFT JOIN hotels h ON h.hotel_id = b.hotel_id
       WHERE b.booking_code = ? FOR UPDATE`,
      [code]
    );
    if (rows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'ไม่พบรายการจองนี้' });
    }

    const { booking_id: bookingId, status, user_id: ownerId } = rows[0];
    const isAdmin = req.user.role === 'admin';
    if (!isAdmin && Number(ownerId) !== Number(req.user.id)) {
      await conn.rollback();
      return res.status(403).json({ success: false, message: 'ไม่มีสิทธิ์ยกเลิกรายการนี้' });
    }
    if (status === 'cancelled') {
      await conn.rollback();
      return res.status(400).json({ success: false, message: 'รายการจองนี้ถูกยกเลิกไปแล้ว' });
    }
    const blocked = isAdmin ? null : cancelBlock(rows[0]);
    if (blocked) {
      await conn.rollback();
      return res.status(400).json({ success: false, message: blocked });
    }

    await conn.query("UPDATE bookings SET status = 'cancelled' WHERE booking_id = ?", [bookingId]);
    await conn.query("UPDATE payments SET status = 'failed' WHERE booking_id = ? AND status = 'pending'", [bookingId]);
    await conn.query(
      'INSERT INTO cancellations (booking_id, reason, additional_details, cancelled_at) VALUES (?, ?, ?, NOW())',
      [bookingId, reason, additionalDetails]
    );

    await conn.commit();
    res.json({ success: true, message: 'ยกเลิกการจองเรียบร้อยแล้ว', bookingId });
  } catch (error) {
    await conn.rollback();
    res.status(500).json({ success: false, message: errText(error) });
  } finally {
    conn.release();
  }
});


// ===== เฉพาะแอดมิน =====
// รายการจองทั้งหมด (ทุกผู้ใช้)
app.get('/api/admin/bookings', authenticate, requireAdmin, async (req, res) => {
  try {
    const c = await userCols();
    const [rows] = await db.query(`
      SELECT b.*, h.name AS hotel_name, h.location AS hotel_location,
             ${c.name ? 'u.' + c.name : 'NULL'} AS user_name, u.${c.email} AS user_email,
             (SELECT reason FROM cancellations WHERE booking_id = b.booking_id ORDER BY cancelled_at DESC LIMIT 1) AS cancel_reason,
             (SELECT additional_details FROM cancellations WHERE booking_id = b.booking_id ORDER BY cancelled_at DESC LIMIT 1) AS cancel_details,
             (SELECT status FROM payments WHERE booking_id = b.booking_id) AS payment_status,
             (SELECT cancelled_at FROM cancellations WHERE booking_id = b.booking_id ORDER BY cancelled_at DESC LIMIT 1) AS cancelled_at
      FROM bookings b
      LEFT JOIN hotels h ON h.hotel_id = b.hotel_id
      LEFT JOIN users u ON u.${c.id} = b.user_id
      ORDER BY b.booking_id DESC
    `);

    // ชื่อห้อง (ไม่ผูกกับชื่อคอลัมน์ใน rooms)
    const roomIds = [...new Set(rows.map((r) => r.room_id).filter((v) => v != null))];
    const roomNames = {};
    if (roomIds.length > 0) {
      const [rooms] = await db.query('SELECT * FROM rooms WHERE room_id IN (?)', [roomIds]);
      rooms.forEach((r) => {
        roomNames[r.room_id] = r.room_type || r.type_name || r.room_name || r.name || null;
      });
    }
    res.json({ success: true, data: rows.map((r) => ({ ...r, slip_file: undefined, has_slip: Boolean(r.slip_file), room_label: roomNames[r.room_id] || 'ห้องพัก' })) });
  } catch (error) {
    res.status(500).json({ success: false, message: errText(error) });
  }
});

app.delete('/api/admin/rooms/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const [r] = await db.query('DELETE FROM rooms WHERE room_id = ?', [req.params.id]);
    if (r.affectedRows === 0) return res.status(404).json({ success: false, message: 'ไม่พบห้องนี้' });
    res.json({ success: true });
  } catch (error) {
    // ห้องที่มีการจองอ้างอิงอยู่จะลบไม่ได้ (foreign key)
    if (error && error.code === 'ER_ROW_IS_REFERENCED_2') {
      return res.status(409).json({ success: false, message: 'ลบไม่ได้ เพราะมีการจองใช้ห้องนี้อยู่' });
    }
    res.status(500).json({ success: false, message: errText(error) });
  }
});

// ฟีเจอร์เสริม: โปรไฟล์ รีวิว แจ้งเตือน ชำระเงิน เครื่องมือแอดมิน (ดู features.js)
require('./features')(app, { authenticate, requireAdmin, errText, userCols, bcrypt });
// แชทลูกค้า ↔ แอดมิน (ดู chat.js)
require('./chat')(app, { authenticate, requireAdmin, errText, userCols });

// ตรวจว่า server ที่รันอยู่เป็นเวอร์ชันล่าสุดหรือไม่: เปิด http://localhost:5000/api/ping ในเบราว์เซอร์
app.get('/api/ping', (req, res) => {
  res.json({ ok: true });
});

app.get('/', (req, res) => {
  res.send('🚀 Backend API พร้อมใช้งานแล้ว!');
});

// เปิดพอร์ตเฉพาะตอนรันด้วย `node server.js` (ตอน require จากเทสต์จะไม่เปิดพอร์ต)
if (require.main === module) app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log('✅ เวอร์ชัน: ยกเลิกการจองผ่าน PUT /api/bookings/:code/cancel (บันทึกลงตาราง cancellations)');
});

module.exports = app;
