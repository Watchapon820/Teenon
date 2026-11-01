const { useServer, userToken, adminToken, fakeDb } = require('./support/harness');
const test = require('node:test');
const assert = require('node:assert/strict');

const call = useServer();
const U = userToken(7);
const A = adminToken(1);

const msg = (id, sender, body = 'สวัสดี') => ({ id, sender_role: sender, body, created_at: '2026-11-01 10:00:00' });

test.describe('แชทฝั่งลูกค้า', () => {
  test('แอดมินใช้เส้นทางของลูกค้าไม่ได้ → 403', async () => {
    for (const [m, p] of [['GET', '/api/chat'], ['POST', '/api/chat'], ['GET', '/api/chat/unread']]) {
      assert.equal((await call(m, p, { token: A, body: m === 'POST' ? { body: 'x' } : undefined })).status, 403, `${m} ${p}`);
    }
  });

  test('GET /api/chat: คืนข้อความตั้งแต่ after พร้อมทำเครื่องหมายว่าอ่านแล้ว และบอกว่าอีกฝั่งอ่านถึงไหน', async () => {
    fakeDb.on(/SELECT id, sender_role, body, created_at FROM support_messages/, [[msg(3, 'admin'), msg(4, 'user')]]);
    fakeDb.on(/SELECT MAX\(id\) AS id FROM support_messages/, [[{ id: 4 }]]);
    const r = await call('GET', '/api/chat?after=2', { token: U });
    assert.equal(r.status, 200);
    assert.deepEqual(r.json.data.map((m) => [m.id, m.mine]), [[3, false], [4, true]]);
    assert.equal(r.json.read_up_to, 4);
    assert.deepEqual(fakeDb.called(/FROM support_messages WHERE user_id = \? AND id > \?/)[0].params, [7, 2, 200]);
    assert.deepEqual(fakeDb.called(/UPDATE support_messages SET read_at/)[0].params, [7, 'admin']);
  });

  test('GET /api/chat: ไม่มีข้อความ → read_up_to เป็น 0 และ after ที่ผิดถือเป็น 0', async () => {
    fakeDb.on(/SELECT MAX\(id\) AS id FROM support_messages/, [[{ id: null }]]);
    const r = await call('GET', '/api/chat?after=abc', { token: U });
    assert.deepEqual(r.json.data, []);
    assert.equal(r.json.read_up_to, 0);
    assert.equal(fakeDb.called(/id > \?/)[0].params[1], 0);
  });

  test('GET /api/chat: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/FROM support_messages WHERE user_id = \? AND id > \?/);
    assert.equal((await call('GET', '/api/chat', { token: U })).status, 500);
  });

  test('POST /api/chat: ข้อความว่าง → 400, ตัดความยาว 1000, บันทึกเป็นข้อความของลูกค้า', async () => {
    assert.equal((await call('POST', '/api/chat', { token: U, body: { body: '   ' } })).status, 400);
    fakeDb.on(/INSERT INTO support_messages/, [{ insertId: 15 }]);
    const r = await call('POST', '/api/chat', { token: U, body: { body: 'ก'.repeat(1500) } });
    assert.equal(r.status, 201);
    assert.equal(r.json.id, 15);
    const p = fakeDb.called(/INSERT INTO support_messages/)[0].params;
    assert.equal(p[0], 7);
    assert.equal(p[2].length, 1000);
  });

  test('POST /api/chat: ส่งเกิน 20 ข้อความต่อนาที → 429 และฐานข้อมูลล่ม → 500', async () => {
    const t = userToken(55);
    let last;
    for (let i = 0; i < 21; i++) last = await call('POST', '/api/chat', { token: t, body: { body: 'x' } });
    assert.equal(last.status, 429);
    fakeDb.fail(/INSERT INTO support_messages/);
    assert.equal((await call('POST', '/api/chat', { token: userToken(56), body: { body: 'x' } })).status, 500);
  });

  test('GET /api/chat/unread: จำนวนข้อความจากทีมงานที่ยังไม่อ่าน', async () => {
    fakeDb.on(/COUNT\(\*\) AS n FROM support_messages WHERE user_id = \? AND sender_role = 'admin'/, [[{ n: '3' }]]);
    assert.equal((await call('GET', '/api/chat/unread', { token: U })).json.unread, 3);
    fakeDb.fail(/COUNT\(\*\) AS n FROM support_messages/);
    assert.equal((await call('GET', '/api/chat/unread', { token: U })).status, 500);
  });
});

test.describe('แชทฝั่งแอดมิน', () => {
  test('ลูกค้าเข้าเส้นทางแอดมินไม่ได้ → 403', async () => {
    for (const p of ['/api/admin/chats', '/api/admin/chats/unread', '/api/admin/chats/7']) {
      assert.equal((await call('GET', p, { token: U })).status, 403, p);
    }
  });

  test('GET /api/admin/chats: กล่องข้อความ แปลง unread เป็นตัวเลข', async () => {
    fakeDb.on(/FROM \(SELECT user_id, MAX\(id\) AS last_id FROM support_messages/, [[{ user_id: 7, last_body: 'สวัสดี', unread: '2', name: 'สมชาย', email: 's@example.com' }]]);
    const r = await call('GET', '/api/admin/chats', { token: A });
    assert.equal(r.json.data[0].unread, 2);
    fakeDb.fail(/FROM \(SELECT user_id, MAX\(id\)/);
    assert.equal((await call('GET', '/api/admin/chats', { token: A })).status, 500);
  });

  test('GET /api/admin/chats/unread: รวมข้อความและจำนวนห้องสนทนา', async () => {
    fakeDb.on(/COUNT\(DISTINCT user_id\) AS chats/, [[{ n: '5', chats: '2' }]]);
    const r = await call('GET', '/api/admin/chats/unread', { token: A });
    assert.deepEqual([r.json.unread, r.json.chats], [5, 2]);
    fakeDb.fail(/COUNT\(DISTINCT user_id\)/);
    assert.equal((await call('GET', '/api/admin/chats/unread', { token: A })).status, 500);
  });

  test('GET /api/admin/chats/:userId: ดูห้องสนทนาของลูกค้า ทำเครื่องหมายว่าอ่านข้อความของลูกค้า', async () => {
    assert.equal((await call('GET', '/api/admin/chats/abc', { token: A })).status, 400);
    fakeDb.on(/SELECT id, sender_role, body, created_at FROM support_messages/, [[msg(1, 'user'), msg(2, 'admin')]]);
    fakeDb.on(/SELECT MAX\(id\) AS id FROM support_messages/, [[{ id: 2 }]]);
    const r = await call('GET', '/api/admin/chats/7?after=0', { token: A });
    assert.deepEqual(r.json.data.map((m) => m.mine), [false, true]);
    assert.deepEqual(fakeDb.called(/UPDATE support_messages SET read_at/)[0].params, [7, 'user']);
    fakeDb.fail(/FROM support_messages WHERE user_id = \? AND id > \?/);
    assert.equal((await call('GET', '/api/admin/chats/7', { token: A })).status, 500);
  });

  test('POST /api/admin/chats/:userId: ตรวจข้อมูล / ไม่ส่งถึงแอดมินด้วยกัน / ไม่พบลูกค้า', async () => {
    const post = (id, body) => call('POST', `/api/admin/chats/${id}`, { token: A, body });
    assert.equal((await post('abc', { body: 'x' })).status, 400);
    assert.equal((await post(7, { body: '  ' })).status, 400);
    assert.equal((await post(7, { body: 'x' })).status, 404);
    fakeDb.on(/SELECT role AS role FROM users/, [[{ role: 'admin' }]]);
    assert.equal((await post(7, { body: 'x' })).status, 404);
  });

  test('POST /api/admin/chats/:userId: แจ้งเตือนลูกค้าเฉพาะข้อความแรกที่ยังไม่ถูกอ่าน', async () => {
    fakeDb.on(/SELECT role AS role FROM users/, [[{ role: 'user' }]]);
    fakeDb.on(/INSERT INTO support_messages/, [{ insertId: 20 }]);
    fakeDb.on(/COUNT\(\*\) AS n FROM support_messages/, [[{ n: 0 }]]);
    const first = await call('POST', '/api/admin/chats/7', { token: A, body: { body: 'ข'.repeat(120) } });
    assert.equal(first.status, 201);
    const note = fakeDb.called(/INSERT INTO notifications/)[0].params;
    assert.equal(note[0], 7);
    assert.equal(note[2].length, 81); // 80 ตัวอักษร + …
    fakeDb.calls.length = 0;
    fakeDb.on(/COUNT\(\*\) AS n FROM support_messages/, [[{ n: 1 }]]);
    assert.equal((await call('POST', '/api/admin/chats/7', { token: A, body: { body: 'อีกข้อความ' } })).status, 201);
    assert.equal(fakeDb.called(/INSERT INTO notifications/).length, 0);
  });

  test('POST /api/admin/chats/:userId: ส่งเกิน 20 ข้อความต่อนาที → 429 และฐานข้อมูลล่ม → 500', async () => {
    const t = adminToken(90);
    let last;
    for (let i = 0; i < 21; i++) last = await call('POST', '/api/admin/chats/7', { token: t, body: { body: 'x' } });
    assert.equal(last.status, 429);
    fakeDb.fail(/SELECT role AS role FROM users/);
    assert.equal((await call('POST', '/api/admin/chats/7', { token: adminToken(91), body: { body: 'x' } })).status, 500);
  });
});
