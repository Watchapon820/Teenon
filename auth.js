// ไฟล์ auth.js — ตัวช่วยเรื่อง JWT และสิทธิ์ (user / admin)
require('dotenv').config();
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET || JWT_SECRET.length < 16 || /change-me/i.test(JWT_SECRET)) {
  throw new Error('ต้องตั้งค่า JWT_SECRET ใน .env เป็นข้อความสุ่มยาวอย่างน้อย 16 ตัวอักษร (ห้ามใช้ค่าตัวอย่าง)');
}

function signToken(user) {
  return jwt.sign({ id: user.user_id, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
}

// ตรวจ token จาก header: Authorization: Bearer <token>
function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ success: false, message: 'กรุณาเข้าสู่ระบบ' });
  try {
    req.user = jwt.verify(token, JWT_SECRET); // { id, role }
    next();
  } catch (_) {
    res.status(401).json({ success: false, message: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่' });
  }
}

function requireAdmin(req, res, next) {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ success: false, message: 'ต้องเป็นแอดมินเท่านั้น' });
  }
  next();
}

module.exports = { signToken, authenticate, requireAdmin };