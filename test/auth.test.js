require('./support/env');
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const { spawnSync } = require('child_process');
const jwt = require('jsonwebtoken');
const { signToken, authenticate, requireAdmin } = require('../auth');

function fakeRes() {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
}

test('signToken ฝัง id และ role และตรวจกลับได้', () => {
  const token = signToken({ user_id: 9, role: 'admin' });
  const p = jwt.verify(token, process.env.JWT_SECRET);
  assert.equal(p.id, 9);
  assert.equal(p.role, 'admin');
  assert.equal(p.exp - p.iat, 7 * 24 * 3600);
});

test('authenticate: ไม่มี token → 401', () => {
  const res = fakeRes();
  let called = false;
  authenticate({ headers: {} }, res, () => { called = true; });
  assert.equal(res.statusCode, 401);
  assert.equal(called, false);
});

test('authenticate: token ผิด/ไม่ใช่ Bearer/เซ็นด้วยคีย์อื่น → 401', () => {
  const forged = jwt.sign({ id: 1, role: 'admin' }, 'some-other-secret-some-other-secret');
  for (const authorization of ['Bearer not-a-token', 'Basic abc', 'Bearer ' + forged]) {
    const res = fakeRes();
    authenticate({ headers: { authorization } }, res, () => assert.fail('ต้องไม่ผ่าน'));
    assert.equal(res.statusCode, 401);
  }
});

test('authenticate: token ที่หมดอายุ → 401', () => {
  const expired = jwt.sign({ id: 1, role: 'user' }, process.env.JWT_SECRET, { expiresIn: -10 });
  const res = fakeRes();
  authenticate({ headers: { authorization: 'Bearer ' + expired } }, res, () => assert.fail('ต้องไม่ผ่าน'));
  assert.equal(res.statusCode, 401);
});

test('authenticate: token ถูกต้อง → ใส่ req.user แล้วไปต่อ', () => {
  const req = { headers: { authorization: 'Bearer ' + signToken({ user_id: 4, role: 'user' }) } };
  let called = false;
  authenticate(req, fakeRes(), () => { called = true; });
  assert.ok(called);
  assert.equal(req.user.id, 4);
  assert.equal(req.user.role, 'user');
});

test('requireAdmin: ผ่านเฉพาะ role admin', () => {
  let res = fakeRes();
  requireAdmin({ user: { role: 'user' } }, res, () => assert.fail('ต้องไม่ผ่าน'));
  assert.equal(res.statusCode, 403);
  res = fakeRes();
  requireAdmin({}, res, () => assert.fail('ต้องไม่ผ่าน'));
  assert.equal(res.statusCode, 403);
  let called = false;
  requireAdmin({ user: { role: 'admin' } }, fakeRes(), () => { called = true; });
  assert.ok(called);
});

test('JWT_SECRET สั้นหรือเป็นค่าตัวอย่าง → โหลด auth.js ไม่ได้', () => {
  for (const secret of ['short', 'please-change-me-please-change-me']) {
    const r = spawnSync(process.execPath, ['-e', "require('./auth')"], {
      cwd: path.join(__dirname, '..'),
      env: { ...process.env, JWT_SECRET: secret },
      encoding: 'utf8',
    });
    assert.notEqual(r.status, 0, `secret "${secret}" ต้องถูกปฏิเสธ`);
    assert.match(r.stderr, /JWT_SECRET/);
  }
});
