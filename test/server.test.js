const { fakeDb } = require('./support/env');
const test = require('node:test');
const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');
const app = require('../server');
const { signToken } = require('../auth');

// ตารางผู้ใช้จำลอง: ชื่อคอลัมน์ตามที่ userCols() รู้จัก
const USER_COLUMNS = ['user_id', 'name', 'email', 'phone', 'password_hash', 'role'].map((Field) => ({ Field }));
let users;

function installDb() {
  fakeDb.reset();
  fakeDb.handler = (sql, params) => {
    if (sql.startsWith('SHOW COLUMNS FROM users')) return [USER_COLUMNS];
    if (sql.startsWith('SELECT 1 FROM users')) return [users.filter((u) => u.email === params[0]).map(() => ({ 1: 1 }))];
    if (sql.startsWith('SELECT * FROM users WHERE email')) return [users.filter((u) => u.email === params[0])];
    if (sql.startsWith('SELECT * FROM users WHERE user_id')) return [users.filter((u) => u.user_id === params[0])];
    if (sql.startsWith('INSERT INTO users')) {
      users.push({ user_id: 100 + users.length, email: params[0], password_hash: params[1], role: params[2], name: params[3], phone: params[4] });
      return [{ insertId: 100 + users.length - 1 }];
    }
    return [[]];
  };
}

let server;
let base;
test.before(async () => {
  users = [];
  installDb();
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
test.after(() => server.close());
test.beforeEach(() => {
  users = [];
  installDb();
});

async function call(method, path, { body, token } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    // ไม่ใช่ JSON
  }
  return { status: res.status, json, text, headers: res.headers };
}

test('GET /api/ping และ / ตอบปกติ พร้อม security headers', async () => {
  const r = await call('GET', '/api/ping');
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { ok: true });
  assert.equal(r.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(r.headers.get('x-frame-options'), 'DENY');
  assert.equal(r.headers.get('x-powered-by'), null);
  assert.equal((await call('GET', '/')).status, 200);
});

test('GET /api/config คืนข้อมูลติดต่อ', async () => {
  const r = await call('GET', '/api/config');
  assert.equal(r.status, 200);
  assert.equal(r.json.success, true);
  assert.ok('phone' in r.json.contact);
});

test('สมัครสมาชิก: ข้อมูลไม่ครบ → 400', async () => {
  assert.equal((await call('POST', '/api/register', { body: { email: 'a@b.com', password: '123' } })).status, 400);
  assert.equal((await call('POST', '/api/register', { body: {} })).status, 400);
});

test('สมัครสมาชิก → ได้ token, role เป็น user เสมอ และรหัสผ่านถูกเข้ารหัส', async () => {
  const r = await call('POST', '/api/register', {
    body: { name: 'สมชาย', email: ' Somchai@Example.com ', password: 'secret123', phone: '0812345678', role: 'admin' },
  });
  assert.equal(r.status, 201);
  assert.equal(r.json.user.role, 'user');
  assert.equal(r.json.user.email, 'somchai@example.com');
  assert.ok(r.json.token);
  assert.notEqual(users[0].password_hash, 'secret123');
  assert.ok(await bcrypt.compare('secret123', users[0].password_hash));
});

test('สมัครด้วยอีเมลซ้ำ → 409', async () => {
  const body = { name: 'ก', email: 'dup@example.com', password: 'secret123' };
  assert.equal((await call('POST', '/api/register', { body })).status, 201);
  assert.equal((await call('POST', '/api/register', { body })).status, 409);
});

test('เข้าสู่ระบบ: รหัสถูก → token ใช้เรียก /api/me ได้', async () => {
  await call('POST', '/api/register', { body: { name: 'มาลี', email: 'mali@example.com', password: 'secret123' } });
  const login = await call('POST', '/api/login', { body: { email: 'MALI@example.com', password: 'secret123' } });
  assert.equal(login.status, 200);
  const me = await call('GET', '/api/me', { token: login.json.token });
  assert.equal(me.status, 200);
  assert.equal(me.json.user.email, 'mali@example.com');
});

test('เข้าสู่ระบบ: รหัสผิดหรือไม่มีบัญชี → 401 ข้อความเดียวกัน', async () => {
  await call('POST', '/api/register', { body: { name: 'ก', email: 'x@example.com', password: 'secret123' } });
  const wrong = await call('POST', '/api/login', { body: { email: 'x@example.com', password: 'nope' } });
  const none = await call('POST', '/api/login', { body: { email: 'nobody@example.com', password: 'secret123' } });
  assert.equal(wrong.status, 401);
  assert.equal(none.status, 401);
  assert.equal(wrong.json.message, none.json.message);
});

test('ฐานข้อมูลล่ม → 500 โดยไม่เปิดเผยรายละเอียด SQL', async (t) => {
  t.mock.method(console, 'error', () => {});
  fakeDb.handler = () => {
    throw Object.assign(new Error('connect ECONNREFUSED 127.0.0.1:3306'), { code: 'ECONNREFUSED' });
  };
  const r = await call('POST', '/api/login', { body: { email: 'a@b.com', password: 'x' } });
  assert.equal(r.status, 500);
  assert.ok(!/ECONNREFUSED|3306/.test(r.text));
});

test('เส้นทางที่ต้องล็อกอินปฏิเสธคำขอที่ไม่มี token', async () => {
  for (const p of ['/api/me', '/api/bookings', '/api/saved', '/api/notifications']) {
    assert.equal((await call('GET', p)).status, 401, p);
  }
});

test('เส้นทางแอดมินปฏิเสธผู้ใช้ทั่วไป (403) แต่เปิดให้แอดมิน', async () => {
  const userToken = signToken({ user_id: 1, role: 'user' });
  const adminToken = signToken({ user_id: 2, role: 'admin' });
  for (const p of ['/api/admin/bookings', '/api/admin/stats', '/api/admin/deals', '/api/admin/chats']) {
    assert.equal((await call('GET', p, { token: userToken })).status, 403, p);
  }
  assert.equal((await call('GET', '/api/admin/bookings', { token: adminToken })).status, 200);
});
