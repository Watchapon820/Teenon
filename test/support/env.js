// ตั้งค่าสภาพแวดล้อมสำหรับเทสต์ — ต้อง require เป็นไฟล์แรกของทุกไฟล์เทสต์
// (dotenv ไม่ทับค่าที่ตั้งไว้แล้ว เทสต์จึงไม่ขึ้นกับไฟล์ .env ของเครื่อง)
process.env.JWT_SECRET = 'test-secret-for-unit-tests-only-1234567890';
process.env.NODE_ENV = 'test';
delete process.env.SMTP_HOST;

// แทน db.js ด้วยตัวปลอม: เทสต์ไม่ต้องต่อ MySQL จริง
// ตั้ง fakeDb.handler = (sql, params) => [rows, ...] เพื่อกำหนดผลของแต่ละคำสั่ง SQL
const dbPath = require.resolve('../../db');
const fakeDb = {
  calls: [],
  handler: () => [[]],
  async query(sql, params) {
    fakeDb.calls.push({ sql: String(sql), params });
    return fakeDb.handler(String(sql), params);
  },
  reset() {
    fakeDb.calls.length = 0;
    fakeDb.handler = () => [[]];
  },
};
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: fakeDb };

module.exports = { fakeDb };
