// ไฟล์ helpers.js — ฟังก์ชันช่วยที่ server.js และ features.js ใช้ร่วมกัน
const fs = require('fs');
const path = require('path');
const db = require('./db');

const UPLOAD_DIR = path.join(__dirname, 'uploads'); // รูปโรงแรม/ห้อง (เปิดสาธารณะ)
const SLIP_DIR = path.join(__dirname, 'private_uploads', 'slips'); // สลิปโอนเงิน (เปิดได้เฉพาะเจ้าของและแอดมิน)
fs.mkdirSync(UPLOAD_DIR, { recursive: true });
fs.mkdirSync(SLIP_DIR, { recursive: true });

const MAX_IMAGE_BYTES = 6 * 1024 * 1024;

// ตรวจชนิดไฟล์จากไบต์แรก (ไม่เชื่อนามสกุลที่ client ส่งมา)
function sniffExt(buf) {
  if (buf.length > 12 && buf[0] === 0xff && buf[1] === 0xd8) return 'jpg';
  if (buf.length > 12 && buf.slice(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (buf.length > 12 && buf.slice(0, 4).toString() === 'GIF8') return 'gif';
  if (buf.length > 12 && buf.slice(0, 4).toString() === 'RIFF' && buf.slice(8, 12).toString() === 'WEBP') return 'webp';
  return null;
}

// บันทึกรูปที่ส่งมาเป็น base64 ลงโฟลเดอร์ dir คืนชื่อไฟล์ หรือ throw Error ที่มี .status = 400
async function saveImage(dir, base64) {
  const raw = String(base64 || '').replace(/^data:[^,]*,/, '');
  if (!raw) throw Object.assign(new Error('ไม่พบข้อมูลรูปภาพ'), { status: 400 });
  const buf = Buffer.from(raw, 'base64');
  if (buf.length > MAX_IMAGE_BYTES) throw Object.assign(new Error('ไฟล์รูปใหญ่เกิน 6 MB'), { status: 400 });
  const ext = sniffExt(buf);
  if (!ext) throw Object.assign(new Error('รองรับเฉพาะไฟล์ jpg, png, webp, gif'), { status: 400 });
  const file = `${Date.now()}-${Math.floor(Math.random() * 1e6)}.${ext}`;
  await fs.promises.writeFile(path.join(dir, file), buf);
  return file;
}

// เพิ่มคอลัมน์ถ้ายังไม่มี (ใช้ตอนเริ่ม server เพื่อให้ฐานข้อมูลเดิมใช้ได้โดยไม่ต้องรัน SQL เอง)
async function ensureColumn(table, column, ddl) {
  const [cols] = await db.query(`SHOW COLUMNS FROM ${table} LIKE ?`, [column]);
  if (cols.length === 0) await db.query(`ALTER TABLE ${table} ADD COLUMN ${column} ${ddl}`);
}

// บันทึกแจ้งเตือนให้ผู้ใช้ (ถ้าพลาดก็ไม่ให้กระทบงานหลัก)
async function notify(userId, title, body) {
  try {
    await db.query('INSERT INTO notifications (user_id, title, body) VALUES (?, ?, ?)', [userId, title, body]);
  } catch (e) {
    console.error('บันทึกการแจ้งเตือนไม่สำเร็จ:', e.message);
  }
}

// วันที่ 'YYYY-MM-DD' บวก n วัน
function addDays(dateStr, n) {
  const d = new Date(dateStr + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

function todayStr() {
  return new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD ตามเวลาเครื่อง
}

// สถานะการจองที่ "ใช้ห้องจริง" = แอดมินกดยืนยันแล้ว (รอยืนยันยังไม่ลดห้องว่าง)
const COUNTED_STATUSES = ['confirmed', 'completed'];

// จำนวนห้อง "ที่ถูกจองพร้อมกันสูงสุด" ของแต่ละห้อง ในช่วงคืน [from, to)
// นับเฉพาะสถานะใน statuses (ค่าเริ่มต้น = ยืนยันแล้ว) — ส่ง ['pending'] เพื่อดูยอดที่รอยืนยัน
// คืน Map(room_id -> จำนวน) — ห้องที่ไม่มีการจองจะไม่อยู่ใน Map (ถือเป็น 0)
async function peakBookedByRoom(conn, from, to, roomIds, statuses = COUNTED_STATUSES) {
  if (roomIds && roomIds.length === 0) return new Map();
  let sql =
    'SELECT room_id, check_in_date, check_out_date, num_rooms FROM bookings WHERE status IN (?) AND check_in_date < ? AND check_out_date > ?';
  const params = [statuses, to, from];
  if (roomIds) {
    sql += ' AND room_id IN (?)';
    params.push(roomIds);
  }
  const [rows] = await conn.query(sql, params);
  const byRoom = new Map();
  for (const b of rows) (byRoom.get(b.room_id) || byRoom.set(b.room_id, []).get(b.room_id)).push(b);
  const peaks = new Map();
  for (const [id, list] of byRoom) {
    // จำนวนที่ถูกจองพร้อมกันจะสูงสุดที่วันเริ่มของช่วง หรือวันเช็คอินวันใดวันหนึ่ง
    const days = new Set([from]);
    for (const b of list) {
      const ci = String(b.check_in_date).slice(0, 10);
      if (ci > from && ci < to) days.add(ci);
    }
    let peak = 0;
    for (const d of days) {
      const used = list
        .filter((b) => String(b.check_in_date).slice(0, 10) <= d && String(b.check_out_date).slice(0, 10) > d)
        .reduce((sum, b) => sum + (Number(b.num_rooms) || 1), 0);
      peak = Math.max(peak, used);
    }
    peaks.set(id, peak);
  }
  return peaks;
}

// ===== ดีล/โปรโมชัน =====
// ดีลที่ใช้ได้ "ตอนนี้" ของแต่ละโรงแรม: เปิดอยู่ และวันนี้อยู่ในช่วง start..end (รวมวันสุดท้าย)
// ถ้าโรงแรมมีหลายดีลซ้อนกัน ใช้ดีลที่ลดมากที่สุด คืน Map(hotel_id -> deal)
async function activeDealsByHotel(conn, hotelId) {
  const today = todayStr();
  const params = [today, today];
  let sql = 'SELECT deal_id, hotel_id, title, description, discount_percent, start_date, end_date FROM deals WHERE is_active = 1 AND start_date <= ? AND end_date >= ?';
  if (hotelId != null) {
    sql += ' AND hotel_id = ?';
    params.push(hotelId);
  }
  sql += ' ORDER BY discount_percent DESC, deal_id';
  const [rows] = await conn.query(sql, params);
  const map = new Map();
  for (const d of rows) if (!map.has(d.hotel_id)) map.set(d.hotel_id, d);
  return map;
}

// ราคาหลังหักส่วนลด % (ปัดเป็นทศนิยม 2 ตำแหน่ง)
function discounted(price, percent) {
  return Math.round(Number(price) * (100 - Number(percent))) / 100;
}

// ข้อมูลดีลที่ส่งให้แอป
function dealView(d) {
  return {
    deal_id: d.deal_id,
    title: d.title,
    description: d.description || '',
    discount_percent: Number(d.discount_percent),
    end_date: String(d.end_date).slice(0, 10),
  };
}

// อ่านช่วงวันที่จาก query (?checkIn=&checkOut=) ถ้าไม่ระบุหรือไม่ถูกต้องใช้ "คืนนี้"
function stayRange(query) {
  const ok = (v) => /^\d{4}-\d{2}-\d{2}$/.test(String(v || ''));
  let from = ok(query?.checkIn) ? String(query.checkIn) : todayStr();
  if (from < todayStr()) from = todayStr();
  let to = ok(query?.checkOut) ? String(query.checkOut) : addDays(from, 1);
  if (to <= from) to = addDays(from, 1);
  return { from, to };
}

// ===== PromptPay QR (EMVCo) =====
function tlv(id, val) {
  return id + String(val.length).padStart(2, '0') + val;
}
function crc16(str) {
  let crc = 0xffff;
  for (const ch of Buffer.from(str)) {
    crc ^= ch << 8;
    for (let i = 0; i < 8; i++) crc = crc & 0x8000 ? (crc << 1) ^ 0x1021 : crc << 1;
    crc &= 0xffff;
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}
// promptpayId = เบอร์มือถือ (0812345678) หรือเลขบัตรประชาชน/ภาษี 13 หลัก
function promptpayPayload(promptpayId, amount) {
  const id = String(promptpayId || '').replace(/\D/g, '');
  if (!id) return null;
  const target = id.length >= 13 ? tlv('02', id) : tlv('01', '0066' + id.replace(/^0/, ''));
  const merchant = tlv('00', 'A000000677010111') + target;
  const data =
    tlv('00', '01') +
    tlv('01', amount ? '12' : '11') +
    tlv('29', merchant) +
    tlv('53', '764') +
    (amount ? tlv('54', Number(amount).toFixed(2)) : '') +
    tlv('58', 'TH') +
    '6304';
  return data + crc16(data);
}

// ===== ส่งอีเมล (ตั้งค่า SMTP_* ใน .env) =====
// ถ้ายังไม่ตั้ง SMTP จะพิมพ์ข้อความลง Terminal แทน (ใช้ตอนพัฒนาเท่านั้น)
let mailer = null;
function getMailer() {
  if (mailer || !process.env.SMTP_HOST) return mailer;
  const nodemailer = require('nodemailer');
  const port = Number(process.env.SMTP_PORT) || 587;
  mailer = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
  });
  return mailer;
}

async function sendMail(to, subject, text) {
  const m = getMailer();
  if (!m) {
    console.warn(`📧 [ยังไม่ตั้ง SMTP — แสดงอีเมลใน Terminal แทน] ถึง ${to}: ${subject}\n${text}`);
    return;
  }
  await m.sendMail({ from: process.env.SMTP_FROM || process.env.SMTP_USER, to, subject, text });
}

module.exports = {
  sendMail,
  UPLOAD_DIR,
  SLIP_DIR,
  saveImage,
  ensureColumn,
  notify,
  addDays,
  todayStr,
  peakBookedByRoom,
  stayRange,
  activeDealsByHotel,
  discounted,
  dealView,
  promptpayPayload,
};
