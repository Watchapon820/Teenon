// ตั้งค่าสภาพแวดล้อมสำหรับเทสต์ — ต้อง require เป็นไฟล์แรกของทุกไฟล์เทสต์
// (dotenv ไม่ทับค่าที่ตั้งไว้แล้ว เทสต์จึงไม่ขึ้นกับไฟล์ .env ของเครื่อง)
process.env.JWT_SECRET = 'test-secret-for-unit-tests-only-1234567890';
process.env.NODE_ENV = 'test';
process.env.TRUST_PROXY = '1'; // ให้เทสต์ระบุ IP ผ่าน X-Forwarded-For (กัน rate limit ชนกันระหว่างเทสต์)
process.env.PROMPTPAY_ID = '0812345678';
process.env.BANK_NAME = 'TestBank';
delete process.env.SMTP_HOST;

// ปิด log ของเซิร์ฟเวอร์ระหว่างเทสต์ (ตั้ง TEST_VERBOSE=1 เพื่อดู)
if (!process.env.TEST_VERBOSE) {
  console.log = () => {};
  console.error = () => {};
}

const USER_COLUMNS = ['user_id', 'name', 'email', 'phone', 'password_hash', 'role', 'avatar_url'].map((Field) => ({ Field }));
const ROOM_COLUMNS = ['room_id', 'hotel_id', 'room_type', 'price_per_night', 'quantity', 'max_guests', 'bed_type', 'size_sqm', 'image_url'].map((Field) => ({ Field }));

// แทน db.js ด้วยตัวปลอม: เทสต์ไม่ต้องต่อ MySQL จริง
// - fakeDb.on(/regex/, ผลลัพธ์ | (params, sql) => ผลลัพธ์) กำหนดผลของคำสั่ง SQL ที่ตรงกับ regex (กฎที่เพิ่มทีหลังมาก่อน)
// - ผลลัพธ์ของ query ต้องเป็นอาร์เรย์แบบ mysql2: [rows] หรือ [{ insertId, affectedRows }]
// - ไม่มีกฎที่ตรง → [[]]
// - fakeDb.handler = (sql, params) => ... ใช้แทนระบบกฎทั้งหมดได้
const dbPath = require.resolve('../../db');
const fakeDb = {
  calls: [],
  tx: [],
  rules: [],
  handler: null,
  on(re, result) {
    fakeDb.rules.unshift({ re, result });
  },
  // ให้คำสั่งที่ตรงกับ regex โยน error
  fail(re, error = new Error('boom')) {
    fakeDb.on(re, () => {
      throw error;
    });
  },
  dispatch(sql, params) {
    for (const r of fakeDb.rules) {
      if (r.re.test(sql)) return typeof r.result === 'function' ? r.result(params, sql) : r.result;
    }
    return [[]];
  },
  async query(sql, params) {
    fakeDb.calls.push({ sql: String(sql), params });
    return (fakeDb.handler || fakeDb.dispatch)(String(sql), params);
  },
  // คำสั่ง SQL ที่เรียกไปแล้วและตรงกับ regex
  called(re) {
    return fakeDb.calls.filter((c) => re.test(c.sql));
  },
  async getConnection() {
    return {
      query: (sql, params) => fakeDb.query(sql, params),
      beginTransaction: async () => fakeDb.tx.push('begin'),
      commit: async () => fakeDb.tx.push('commit'),
      rollback: async () => fakeDb.tx.push('rollback'),
      release: () => fakeDb.tx.push('release'),
    };
  },
  reset() {
    fakeDb.calls.length = 0;
    fakeDb.tx.length = 0;
    fakeDb.rules.length = 0;
    fakeDb.handler = null;
    fakeDb.on(/^\s*SHOW COLUMNS FROM users/, [USER_COLUMNS]);
    fakeDb.on(/^\s*SHOW COLUMNS FROM rooms/, [ROOM_COLUMNS]);
  },
};
fakeDb.reset();
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: fakeDb };

module.exports = { fakeDb };
