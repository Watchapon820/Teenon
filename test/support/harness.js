// ตัวช่วยสำหรับเทสต์ที่เรียก API ผ่าน HTTP จริง (เปิดเซิร์ฟเวอร์ชั่วคราวบนพอร์ตสุ่ม)
const { fakeDb } = require('./env');
const test = require('node:test');
const fs = require('fs');
const path = require('path');
const { signToken } = require('../../auth');

const userToken = (id = 7) => signToken({ user_id: id, role: 'user' });
const adminToken = (id = 1) => signToken({ user_id: id, role: 'admin' });

// เปิดเซิร์ฟเวอร์ก่อนเทสต์ทั้งไฟล์ และรีเซ็ตฐานข้อมูลจำลองก่อนทุกเทสต์ — คืนฟังก์ชัน call สำหรับยิง API
function useServer() {
  const app = require('../../server');
  let server;
  let base;
  let seq = 0;
  test.before(async () => {
    server = app.listen(0, '127.0.0.1');
    await new Promise((resolve) => server.once('listening', resolve));
    base = `http://127.0.0.1:${server.address().port}`;
  });
  test.after(() => server.close());
  test.beforeEach(() => fakeDb.reset());

  // ip: ระบุเองเพื่อทดสอบ rate limit; ไม่ระบุ = IP ใหม่ทุกครั้ง
  return async function call(method, url, { body, token, ip } = {}) {
    const res = await fetch(base + url, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-Forwarded-For': ip || `10.1.${Math.floor(++seq / 250)}.${seq % 250}`,
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    let json = null;
    try {
      json = JSON.parse(text);
    } catch {
      // ไม่ใช่ JSON
    }
    return { status: res.status, json, text, headers: res.headers };
  };
}

// จดไฟล์ในโฟลเดอร์ก่อนเทสต์ แล้วลบไฟล์ที่เทสต์สร้างเพิ่ม (ไม่ให้เทสต์ทิ้งขยะในโฟลเดอร์ uploads จริง)
function cleanDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
  const before = new Set(fs.readdirSync(dir));
  test.after(() => {
    for (const f of fs.readdirSync(dir)) {
      if (!before.has(f)) fs.rmSync(path.join(dir, f), { recursive: true, force: true });
    }
  });
}

const PNG_BASE64 = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(32)]).toString('base64');

module.exports = { useServer, cleanDir, userToken, adminToken, PNG_BASE64, fakeDb };
