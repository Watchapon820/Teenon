const { useServer, userToken, adminToken, fakeDb } = require('./support/harness');
const test = require('node:test');
const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');
const { addDays, todayStr } = require('../helpers');

const call = useServer();

const USER = { user_id: 7, name: 'สมชาย', email: 'somchai@example.com', phone: '0812345678', password_hash: '', role: 'user' };
const future = (n) => addDays(todayStr(), n);

// ---------- ลืมรหัสผ่าน / ตั้งรหัสผ่านใหม่ ----------
test.describe('ลืม/ตั้งรหัสผ่านใหม่', () => {
  const findUser = (u) => fakeDb.on(/SELECT \* FROM users WHERE email/, [u ? [u] : []]);

  test('forgot-password: ไม่กรอกอีเมล → 400', async () => {
    assert.equal((await call('POST', '/api/forgot-password', { body: {} })).status, 400);
  });

  test('forgot-password: ไม่มีบัญชี/เป็นแอดมิน → ตอบเหมือนกัน และไม่สร้างรหัส', async () => {
    findUser(null);
    const a = await call('POST', '/api/forgot-password', { body: { email: 'nobody@example.com' } });
    findUser({ ...USER, role: 'admin' });
    const b = await call('POST', '/api/forgot-password', { body: { email: 'admin@example.com' } });
    assert.equal(a.status, 200);
    assert.deepEqual(a.json, b.json);
    assert.equal(fakeDb.called(/REPLACE INTO password_resets/).length, 0);
  });

  test('forgot-password → reset-password: ใช้รหัส 6 หลักที่ส่งทางอีเมลตั้งรหัสใหม่ได้ครั้งเดียว', async (t) => {
    const warn = t.mock.method(console, 'warn', () => {});
    findUser(USER);
    const sent = await call('POST', '/api/forgot-password', { body: { email: 'Somchai@Example.com' } });
    assert.equal(sent.status, 200);
    const mailText = warn.mock.calls[0].arguments[0];
    const code = /รหัสยืนยันของคุณคือ (\d{6})/.exec(mailText)[1];
    const hash = fakeDb.called(/REPLACE INTO password_resets/)[0].params[1];

    fakeDb.on(/FROM password_resets WHERE email/, [[{ code_hash: hash, attempts: 0, valid: 1 }]]);
    const ok = await call('POST', '/api/reset-password', { body: { email: USER.email, code, password: 'newpass123' } });
    assert.equal(ok.status, 200);
    const upd = fakeDb.called(/UPDATE users SET password_hash/)[0];
    assert.ok(await bcrypt.compare('newpass123', upd.params[0]));
    assert.equal(fakeDb.called(/DELETE FROM password_resets/).length, 1);
  });

  test('forgot-password: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/SELECT \* FROM users WHERE email/);
    assert.equal((await call('POST', '/api/forgot-password', { body: { email: 'a@b.com' } })).status, 500);
  });

  test('reset-password: ข้อมูลไม่ครบ/รหัสไม่ใช่ 6 หลัก → 400', async () => {
    for (const body of [{}, { email: 'a@b.com', code: '12', password: 'secret1' }, { email: 'a@b.com', code: '123456', password: '123' }]) {
      assert.equal((await call('POST', '/api/reset-password', { body })).status, 400);
    }
  });

  test('reset-password: ไม่มีบัญชี / ไม่มีรหัสที่ขอไว้ / หมดอายุ / ผิดเกิน 5 ครั้ง → 400', async () => {
    const body = { email: USER.email, code: '123456', password: 'secret123' };
    findUser(null);
    assert.equal((await call('POST', '/api/reset-password', { body })).status, 400);
    findUser(USER);
    assert.equal((await call('POST', '/api/reset-password', { body })).status, 400); // ไม่มีแถว password_resets
    fakeDb.on(/FROM password_resets WHERE email/, [[{ code_hash: 'x', attempts: 0, valid: 0 }]]);
    assert.equal((await call('POST', '/api/reset-password', { body })).status, 400);
    fakeDb.on(/FROM password_resets WHERE email/, [[{ code_hash: 'x', attempts: 5, valid: 1 }]]);
    assert.equal((await call('POST', '/api/reset-password', { body })).status, 400);
  });

  test('reset-password: รหัสผิด → นับจำนวนครั้งที่ผิด และไม่เปลี่ยนรหัสผ่าน', async () => {
    findUser(USER);
    fakeDb.on(/FROM password_resets WHERE email/, [[{ code_hash: await bcrypt.hash('111111', 4), attempts: 1, valid: 1 }]]);
    const r = await call('POST', '/api/reset-password', { body: { email: USER.email, code: '222222', password: 'secret123' } });
    assert.equal(r.status, 400);
    assert.equal(fakeDb.called(/UPDATE password_resets SET attempts/).length, 1);
    assert.equal(fakeDb.called(/UPDATE users SET/).length, 0);
  });

  test('reset-password: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/SELECT \* FROM users WHERE email/);
    const r = await call('POST', '/api/reset-password', { body: { email: USER.email, code: '123456', password: 'secret123' } });
    assert.equal(r.status, 500);
  });
});

test('ล็อกอิน/สมัคร: เกิน 20 ครั้งต่อ IP → 429', async () => {
  let last;
  for (let i = 0; i < 21; i++) last = await call('POST', '/api/forgot-password', { body: {}, ip: '203.0.113.9' });
  assert.equal(last.status, 429);
});

test('GET /api/me: ไม่พบผู้ใช้ → 404 และฐานข้อมูลล่ม → 500', async () => {
  assert.equal((await call('GET', '/api/me', { token: userToken() })).status, 404);
  fakeDb.fail(/SELECT \* FROM users WHERE user_id/);
  assert.equal((await call('GET', '/api/me', { token: userToken() })).status, 500);
});

test('POST /api/login: ฐานข้อมูลล่ม → 500', async () => {
  fakeDb.fail(/SELECT \* FROM users WHERE email/);
  assert.equal((await call('POST', '/api/login', { body: { email: 'a@b.com', password: 'x' } })).status, 500);
});

// ---------- โรงแรม ----------
const HOTELS = [
  { hotel_id: 1, name: 'A', starting_price: 1000, rating: 4.5 },
  { hotel_id: 2, name: 'B', starting_price: null, rating: 0 },
];

function seedHotels() {
  fakeDb.on(/FROM hotels h\s+LEFT JOIN rooms r/, [HOTELS]);
  fakeDb.on(/SELECT hotel_id, tag_name FROM hotel_tags/, [[{ hotel_id: 1, tag_name: 'ติดทะเล' }, { hotel_id: 1, tag_name: 'รีสอร์ท' }]]);
  fakeDb.on(/SELECT room_id, hotel_id, quantity FROM rooms/, [[{ room_id: 10, hotel_id: 1, quantity: 5 }, { room_id: 11, hotel_id: 1, quantity: 2 }]]);
  fakeDb.on(/FROM bookings WHERE status IN/, [[{ room_id: 10, check_in_date: todayStr(), check_out_date: future(2), num_rooms: 3 }]]);
  fakeDb.on(/FROM deals WHERE is_active/, [[{ deal_id: 5, hotel_id: 1, title: 'ลด 20%', description: null, discount_percent: 20, start_date: todayStr(), end_date: future(5) }]]);
}

test.describe('โรงแรม', () => {
  test('GET /api/hotels: รวมแท็ก ดีล ราคาหลังลด และห้องว่าง', async () => {
    seedHotels();
    const r = await call('GET', '/api/hotels');
    assert.equal(r.status, 200);
    const [a, b] = r.json.data;
    assert.deepEqual(a.tags, ['ติดทะเล', 'รีสอร์ท']);
    assert.equal(a.deal.discount_percent, 20);
    assert.equal(a.deal_price, 800);
    assert.equal(a.rooms_total, 7);
    assert.equal(a.rooms_available, 4); // 7 - 3 ที่ยืนยันแล้ว
    assert.equal(b.deal, null);
    assert.equal(b.deal_price, null);
    assert.equal(b.rooms_total, 0);
    assert.deepEqual(b.tags, []);
  });

  test('GET /api/hotels: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/FROM hotels h\s+LEFT JOIN rooms r/);
    assert.equal((await call('GET', '/api/hotels')).status, 500);
  });

  test('GET /api/hotels/:id: ไม่พบ → 404', async () => {
    assert.equal((await call('GET', '/api/hotels/99')).status, 404);
  });

  test('GET /api/hotels/:id: รวมห้อง แท็ก รูป ดีล และจำนวนห้องว่าง', async () => {
    fakeDb.on(/FROM hotels h WHERE h\.hotel_id = \?/, [[{ hotel_id: 1, name: 'A', rating: 4.5 }]]);
    fakeDb.on(/SELECT \* FROM rooms WHERE hotel_id/, [[{ room_id: 10, quantity: 5, price_per_night: 1000 }, { room_id: 11, quantity: 2, price_per_night: 2000 }]]);
    fakeDb.on(/SELECT tag_name FROM hotel_tags/, [[{ tag_name: 'สระว่ายน้ำ' }]]);
    fakeDb.on(/SELECT image_url FROM hotel_images/, [[{ image_url: '/uploads/a.jpg' }]]);
    fakeDb.on(/FROM bookings WHERE status IN/, [[{ room_id: 10, check_in_date: todayStr(), check_out_date: future(1), num_rooms: 2 }]]);
    fakeDb.on(/FROM deals WHERE is_active/, [[{ deal_id: 5, hotel_id: 1, title: 'ลด 10%', discount_percent: 10, end_date: future(3) }]]);
    const r = await call('GET', '/api/hotels/1');
    assert.equal(r.status, 200);
    const d = r.json.data;
    assert.deepEqual(d.tags, ['สระว่ายน้ำ']);
    assert.deepEqual(d.images, ['/uploads/a.jpg']);
    assert.equal(d.rooms[0].rooms_available, 3);
    assert.equal(d.rooms[0].deal_price, 900);
    assert.equal(d.rooms_total, 7);
    assert.equal(d.rooms_available, 5);
    assert.equal(d.deal.title, 'ลด 10%');
  });

  test('GET /api/hotels/:id: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/FROM hotels h WHERE h\.hotel_id = \?/);
    assert.equal((await call('GET', '/api/hotels/1')).status, 500);
  });

  test('POST /api/hotels: ต้องเป็นแอดมินและมีชื่อ', async () => {
    assert.equal((await call('POST', '/api/hotels', { token: userToken(), body: { name: 'X' } })).status, 403);
    assert.equal((await call('POST', '/api/hotels', { token: adminToken(), body: { name: '  ' } })).status, 400);
  });

  test('POST /api/hotels: เพิ่มโรงแรม ใช้ค่าเริ่มต้นเมื่อไม่ส่งมา', async () => {
    fakeDb.on(/INSERT INTO hotels/, [{ insertId: 42 }]);
    const r = await call('POST', '/api/hotels', { token: adminToken(), body: { name: 'โรงแรมใหม่' } });
    assert.equal(r.status, 201);
    assert.equal(r.json.hotelId, 42);
    const p = fakeDb.called(/INSERT INTO hotels/)[0].params;
    assert.deepEqual(p.slice(0, 1).concat(p.slice(4)), ['โรงแรมใหม่', '14:00:00', '12:00:00', 1, 1, 1, null]);
  });

  test('POST /api/hotels: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/INSERT INTO hotels/);
    assert.equal((await call('POST', '/api/hotels', { token: adminToken(), body: { name: 'X' } })).status, 500);
  });
});

test.describe('โรงแรมที่บันทึกไว้', () => {
  test('GET /api/saved: คืนรายการพร้อมห้องว่างและดีล', async () => {
    fakeDb.on(/FROM saved_hotels s/, [[{ hotel_id: 1, starting_price: 500 }]]);
    fakeDb.on(/SELECT room_id, hotel_id, quantity FROM rooms/, [[{ room_id: 10, hotel_id: 1, quantity: 4 }]]);
    const r = await call('GET', '/api/saved', { token: userToken() });
    assert.equal(r.status, 200);
    assert.equal(r.json.data[0].rooms_total, 4);
    assert.equal(r.json.data[0].rooms_available, 4);
  });

  test('PUT /api/saved/:id: ไม่มีโรงแรม → 404, มี → บันทึก', async () => {
    assert.equal((await call('PUT', '/api/saved/9', { token: userToken() })).status, 404);
    fakeDb.on(/SELECT 1 FROM hotels WHERE hotel_id/, [[{ 1: 1 }]]);
    assert.equal((await call('PUT', '/api/saved/9', { token: userToken() })).status, 200);
    assert.deepEqual(fakeDb.called(/INSERT IGNORE INTO saved_hotels/)[0].params, [7, '9']);
  });

  test('DELETE /api/saved/:id: ลบเฉพาะของผู้ใช้คนนั้น', async () => {
    assert.equal((await call('DELETE', '/api/saved/9', { token: userToken() })).status, 200);
    assert.deepEqual(fakeDb.called(/DELETE FROM saved_hotels/)[0].params, [7, '9']);
  });

  test('ฐานข้อมูลล่ม → 500 ทั้งสามเส้นทาง', async () => {
    fakeDb.fail(/saved_hotels|SELECT 1 FROM hotels/);
    for (const [m, p] of [['GET', '/api/saved'], ['PUT', '/api/saved/1'], ['DELETE', '/api/saved/1']]) {
      assert.equal((await call(m, p, { token: userToken() })).status, 500, `${m} ${p}`);
    }
  });
});

// ---------- การจอง ----------
test.describe('POST /api/bookings', () => {
  const body = (over = {}) => ({ hotelId: 1, roomId: 10, guestName: 'สมชาย', checkIn: future(3), checkOut: future(5), numRooms: 1, numGuests: 2, ...over });
  const post = (b, token = userToken()) => call('POST', '/api/bookings', { token, body: b });
  const room = (over = {}) => fakeDb.on(/FROM rooms WHERE room_id = \? AND hotel_id = \? FOR UPDATE/, [[{ price_per_night: 1000, quantity: 3, max_guests: 2, ...over }]]);

  test('ข้อมูลไม่ถูกต้อง → 400 (ไม่มีห้อง/วันที่ผิด/ออกก่อนเข้า/ย้อนหลัง/เกิน 60 คืน)', async () => {
    for (const b of [
      body({ hotelId: undefined }),
      body({ roomId: undefined }),
      body({ checkIn: 'abc' }),
      body({ checkOut: future(3) }),
      body({ checkIn: addDays(todayStr(), -2), checkOut: future(1) }),
      body({ checkIn: future(1), checkOut: future(70) }),
    ]) {
      assert.equal((await post(b)).status, 400, JSON.stringify(b));
    }
    assert.equal(fakeDb.tx.length, 0);
  });

  test('ไม่พบห้องในโรงแรมที่เลือก → 400 และย้อนกลับธุรกรรม', async () => {
    const r = await post(body());
    assert.equal(r.status, 400);
    assert.deepEqual(fakeDb.tx, ['begin', 'rollback', 'release']);
  });

  test('จำนวนผู้เข้าพักเกินที่ห้องรับได้ → 400', async () => {
    room({ max_guests: 2 });
    const r = await post(body({ numGuests: 5 }));
    assert.equal(r.status, 400);
    assert.match(r.json.message, /สูงสุด 2 คน/);
  });

  test('ห้องเต็มในช่วงวันที่เลือก → 409', async () => {
    room({ quantity: 1 });
    fakeDb.on(/FROM bookings WHERE room_id = \? AND status IN/, [[{ check_in_date: future(3), check_out_date: future(5), num_rooms: 1 }]]);
    const r = await post(body());
    assert.equal(r.status, 409);
    assert.match(r.json.message, /เต็ม/);
  });

  test('ห้องเหลือน้อยกว่าที่ขอ → 409 บอกจำนวนที่เหลือ', async () => {
    room({ quantity: 3, max_guests: 4 });
    fakeDb.on(/FROM bookings WHERE room_id = \? AND status IN/, [[{ check_in_date: future(3), check_out_date: future(4), num_rooms: 2 }]]);
    const r = await post(body({ numRooms: 2 }));
    assert.equal(r.status, 409);
    assert.match(r.json.message, /เหลือเพียง 1 ห้อง/);
  });

  test('จองสำเร็จ: คิดราคาที่ server จากราคาห้อง ไม่เชื่อ body และรอยืนยัน', async () => {
    room();
    fakeDb.on(/INSERT INTO bookings/, [{ insertId: 77 }]);
    const r = await post(body({ userId: 999, totalAmount: 1, numRooms: 1 }));
    assert.equal(r.status, 201);
    assert.match(r.json.bookingCode, /^TN-[A-Z2-9]{8}$/);
    assert.equal(r.json.totalAmount, 2000); // 2 คืน x 1000
    assert.equal(r.json.discountAmount, 0);
    assert.equal(r.json.dealTitle, null);
    const ins = fakeDb.called(/INSERT INTO bookings/)[0].params;
    assert.equal(ins[1], 7); // user_id จาก token
    assert.deepEqual(fakeDb.tx, ['begin', 'commit', 'release']);
    assert.equal(fakeDb.called(/INSERT INTO notifications/).length, 1);
  });

  test('จองสำเร็จพร้อมดีล: หักส่วนลด % ต่อคืน', async () => {
    room();
    fakeDb.on(/FROM deals WHERE is_active/, [[{ deal_id: 5, hotel_id: 1, title: 'ลด 25%', discount_percent: 25 }]]);
    fakeDb.on(/INSERT INTO bookings/, [{ insertId: 78 }]);
    const r = await post(body());
    assert.equal(r.status, 201);
    assert.equal(r.json.totalAmount, 1500);
    assert.equal(r.json.originalAmount, 2000);
    assert.equal(r.json.discountAmount, 500);
    assert.equal(r.json.dealTitle, 'ลด 25%');
    assert.equal(r.json.discountPercent, 25);
  });

  test('สุ่มรหัสจองซ้ำครบ 10 ครั้ง → 500', async () => {
    room();
    fakeDb.on(/SELECT 1 FROM bookings WHERE booking_code/, [[{ 1: 1 }]]);
    assert.equal((await post(body())).status, 500);
    assert.ok(fakeDb.tx.includes('rollback'));
  });

  test('ฐานข้อมูลล่มระหว่างจอง → 500 และย้อนกลับ', async () => {
    room();
    fakeDb.fail(/INSERT INTO bookings/);
    assert.equal((await post(body())).status, 500);
    assert.ok(fakeDb.tx.includes('rollback'));
    assert.ok(fakeDb.tx.includes('release'));
  });
});

test.describe('GET /api/bookings และนโยบายยกเลิก', () => {
  const row = (over) => ({ booking_id: 1, room_id: 10, status: 'pending', check_in_date: future(10), free_cancel_days: 3, slip_file: null, ...over });
  const list = async (rows) => {
    fakeDb.on(/b\.status <> 'cancelled'/, [rows]);
    fakeDb.on(/SELECT \* FROM rooms WHERE room_id IN/, [[{ room_id: 10, room_type: 'Deluxe' }]]);
    return (await call('GET', '/api/bookings', { token: userToken() })).json.data;
  };

  test('เรียงล่าสุดก่อน แนบชื่อห้อง ซ่อนไฟล์สลิป', async () => {
    const data = await list([row({ booking_id: 1 }), row({ booking_id: 3, slip_file: 'x.png' }), row({ booking_id: 2, room_id: 99 })]);
    assert.deepEqual(data.map((d) => d.booking_id), [3, 2, 1]);
    assert.equal(data[0].room_label, 'Deluxe');
    assert.equal(data[1].room_label, 'ห้องพัก');
    assert.equal(data[0].has_slip, true);
    assert.equal(data[0].slip_file, undefined);
  });

  test('cancel_block: ยกเลิกได้ / เลยช่วงฟรี / เลยวันเช็คอิน / สถานะที่ยกเลิกไม่ได้', async () => {
    const data = await list([
      row({ booking_id: 1 }), // รอยืนยัน ไม่มีสลิป → ได้
      row({ booking_id: 2, status: 'confirmed', check_in_date: future(10) }), // จ่ายแล้ว แต่ยังอยู่ในช่วงฟรี → ได้
      row({ booking_id: 3, status: 'confirmed', check_in_date: future(1), free_cancel_days: 3 }), // เลยช่วงฟรี
      row({ booking_id: 4, check_in_date: addDays(todayStr(), -1) }), // เลยวันเช็คอิน
      row({ booking_id: 5, status: 'completed' }),
      row({ booking_id: 6, status: 'cancelled' }),
    ]);
    const by = Object.fromEntries(data.map((d) => [d.booking_id, d.cancel_block]));
    assert.equal(by[1], null);
    assert.equal(by[2], null);
    assert.match(by[3], /เลยช่วงยกเลิกฟรี/);
    assert.match(by[4], /เลยวันเช็คอิน/);
    assert.match(by[5], /ยกเลิกไม่ได้แล้ว/);
    assert.match(by[6], /ถูกยกเลิกไปแล้ว/);
  });

  test('ไม่มีรายการ → ไม่ query ห้อง และฐานข้อมูลล่ม → 500', async () => {
    assert.deepEqual(await list([]), []);
    fakeDb.fail(/b\.status <> 'cancelled'/);
    assert.equal((await call('GET', '/api/bookings', { token: userToken() })).status, 500);
  });
});

test.describe('PUT /api/bookings/:code/cancel', () => {
  const found = (over = {}) =>
    fakeDb.on(/b\.booking_code = \? FOR UPDATE/, [[{ booking_id: 5, status: 'pending', user_id: 7, check_in_date: future(10), slip_file: null, free_cancel_days: 3, ...over }]]);
  const cancel = (token, body) => call('PUT', '/api/bookings/TN-ABC/cancel', { token, body });

  test('ไม่พบรายการ → 404', async () => {
    assert.equal((await cancel(userToken())).status, 404);
    assert.ok(fakeDb.tx.includes('rollback'));
  });

  test('ยกเลิกของคนอื่น → 403', async () => {
    found({ user_id: 8 });
    assert.equal((await cancel(userToken())).status, 403);
  });

  test('ยกเลิกไปแล้ว → 400', async () => {
    found({ status: 'cancelled' });
    assert.equal((await cancel(userToken())).status, 400);
  });

  test('ติดนโยบายยกเลิก (เลยวันเช็คอิน) → 400', async () => {
    found({ check_in_date: addDays(todayStr(), -1) });
    assert.equal((await cancel(userToken())).status, 400);
  });

  test('ลูกค้ายกเลิกของตัวเอง: บันทึกเหตุผลและตัดความยาว', async () => {
    found();
    const r = await cancel(userToken(), { reason: 'ก'.repeat(150), additionalDetails: ' เปลี่ยนแผน ' });
    assert.equal(r.status, 200);
    const ins = fakeDb.called(/INSERT INTO cancellations/)[0].params;
    assert.equal(ins[1].length, 100);
    assert.equal(ins[2], 'เปลี่ยนแผน');
    assert.deepEqual(fakeDb.tx, ['begin', 'commit', 'release']);
  });

  test('ไม่ระบุเหตุผล → "ไม่ระบุ"', async () => {
    found();
    await cancel(userToken());
    assert.equal(fakeDb.called(/INSERT INTO cancellations/)[0].params[1], 'ไม่ระบุ');
  });

  test('แอดมินยกเลิกรายการของคนอื่นได้แม้เลยกำหนด', async () => {
    found({ user_id: 8, check_in_date: addDays(todayStr(), -3) });
    assert.equal((await cancel(adminToken())).status, 200);
  });

  test('ฐานข้อมูลล่ม → 500 และย้อนกลับ', async () => {
    found();
    fakeDb.fail(/INSERT INTO cancellations/);
    assert.equal((await cancel(userToken())).status, 500);
    assert.ok(fakeDb.tx.includes('rollback'));
  });
});

test.describe('เฉพาะแอดมิน', () => {
  test('GET /api/admin/bookings: แนบชื่อห้องและซ่อนสลิป', async () => {
    fakeDb.on(/LEFT JOIN users u ON u\./, [[{ booking_id: 1, room_id: 10, slip_file: 's.png' }, { booking_id: 2, room_id: 11, slip_file: null }]]);
    fakeDb.on(/SELECT \* FROM rooms WHERE room_id IN/, [[{ room_id: 10, name: 'Suite' }]]);
    const r = await call('GET', '/api/admin/bookings', { token: adminToken() });
    assert.equal(r.status, 200);
    assert.equal(r.json.data[0].room_label, 'Suite');
    assert.equal(r.json.data[0].has_slip, true);
    assert.equal(r.json.data[0].slip_file, undefined);
    assert.equal(r.json.data[1].room_label, 'ห้องพัก');
  });

  test('GET /api/admin/bookings: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/LEFT JOIN users u ON u\./);
    assert.equal((await call('GET', '/api/admin/bookings', { token: adminToken() })).status, 500);
  });

  test('DELETE /api/admin/rooms/:id: 404 / 409 (มีการจองอ้างอิง) / สำเร็จ / 500', async () => {
    const del = () => call('DELETE', '/api/admin/rooms/10', { token: adminToken() });
    fakeDb.on(/DELETE FROM rooms WHERE room_id/, [{ affectedRows: 0 }]);
    assert.equal((await del()).status, 404);
    fakeDb.on(/DELETE FROM rooms WHERE room_id/, [{ affectedRows: 1 }]);
    assert.equal((await del()).status, 200);
    fakeDb.fail(/DELETE FROM rooms WHERE room_id/, Object.assign(new Error('fk'), { code: 'ER_ROW_IS_REFERENCED_2' }));
    assert.equal((await del()).status, 409);
    fakeDb.fail(/DELETE FROM rooms WHERE room_id/);
    assert.equal((await del()).status, 500);
  });
});
