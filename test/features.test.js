const { useServer, cleanDir, userToken, adminToken, PNG_BASE64, fakeDb } = require('./support/harness');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { addDays, todayStr, UPLOAD_DIR, SLIP_DIR } = require('../helpers');

const call = useServer();
cleanDir(UPLOAD_DIR);
cleanDir(path.join(UPLOAD_DIR, 'avatars'));
cleanDir(SLIP_DIR);

const future = (n) => addDays(todayStr(), n);
const U = userToken();
const A = adminToken();

test('GET /api/config: คืนข้อมูลติดต่อจาก env', async () => {
  process.env.CONTACT_PHONE = '02-000-0000';
  const r = await call('GET', '/api/config');
  assert.equal(r.json.contact.phone, '02-000-0000');
  delete process.env.CONTACT_PHONE;
});

test.describe('โปรไฟล์', () => {
  const me = { user_id: 7, name: 'สมชาย', email: 's@example.com', phone: '0812345678', role: 'user', avatar_url: null, password_hash: '' };

  test('PUT /api/me: ตรวจชื่อและเบอร์โทร', async () => {
    assert.equal((await call('PUT', '/api/me', { token: U, body: { name: ' ' } })).status, 400);
    assert.equal((await call('PUT', '/api/me', { token: U, body: { name: 'ก', phone: 'abc' } })).status, 400);
  });

  test('PUT /api/me: แก้ชื่อ/เบอร์แล้วคืนข้อมูลล่าสุด', async () => {
    fakeDb.on(/SELECT \* FROM users WHERE user_id/, [[{ ...me, name: 'ชื่อใหม่' }]]);
    const r = await call('PUT', '/api/me', { token: U, body: { name: 'ชื่อใหม่', phone: '081-234-5678' } });
    assert.equal(r.status, 200);
    assert.equal(r.json.user.name, 'ชื่อใหม่');
    assert.deepEqual(fakeDb.called(/UPDATE users SET name = \?, phone = \?/)[0].params, ['ชื่อใหม่', '081-234-5678', 7]);
  });

  test('PUT /api/me: ฐานข้อมูลล่ม → 500', async () => {
    fakeDb.fail(/UPDATE users SET name/);
    assert.equal((await call('PUT', '/api/me', { token: U, body: { name: 'ก' } })).status, 500);
  });

  test('PUT /api/me/avatar: ไม่พบผู้ใช้ → 404', async () => {
    assert.equal((await call('PUT', '/api/me/avatar', { token: U, body: { data: PNG_BASE64 } })).status, 404);
  });

  test('PUT /api/me/avatar: บันทึกรูปใหม่และลบรูปเก่า', async () => {
    const oldName = `old-${process.pid}.png`;
    const oldFile = path.join(UPLOAD_DIR, 'avatars', oldName);
    fs.writeFileSync(oldFile, 'x');
    fakeDb.on(/SELECT avatar_url FROM users/, [[{ avatar_url: '/uploads/avatars/' + oldName }]]);
    const r = await call('PUT', '/api/me/avatar', { token: U, body: { data: PNG_BASE64 } });
    assert.equal(r.status, 200);
    assert.match(r.json.avatar, /^\/uploads\/avatars\/.+\.png$/);
    assert.ok(fs.existsSync(path.join(UPLOAD_DIR, 'avatars', path.basename(r.json.avatar))));
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.equal(fs.existsSync(oldFile), false);
  });

  test('PUT /api/me/avatar: ไม่ใช่รูป → 400 (ไม่เชื่อนามสกุล)', async () => {
    fakeDb.on(/SELECT avatar_url FROM users/, [[{ avatar_url: null }]]);
    const r = await call('PUT', '/api/me/avatar', { token: U, body: { data: Buffer.from('not an image at all').toString('base64') } });
    assert.equal(r.status, 400);
  });

  test('DELETE /api/me/avatar: ล้างรูป และฐานข้อมูลล่ม → 500', async () => {
    fakeDb.on(/SELECT avatar_url FROM users/, [[{ avatar_url: '/uploads/avatars/none.png' }]]);
    assert.equal((await call('DELETE', '/api/me/avatar', { token: U })).status, 200);
    assert.equal(fakeDb.called(/SET avatar_url = NULL/).length, 1);
    fakeDb.fail(/SET avatar_url = NULL/);
    assert.equal((await call('DELETE', '/api/me/avatar', { token: U })).status, 500);
  });

  test('PUT /api/me/password: รหัสใหม่สั้น / รหัสเดิมผิด / สำเร็จ', async () => {
    assert.equal((await call('PUT', '/api/me/password', { token: U, body: { currentPassword: 'a', newPassword: '123' } })).status, 400);
    fakeDb.on(/SELECT password_hash AS p FROM users/, [[{ p: await bcrypt.hash('oldpass', 4) }]]);
    assert.equal((await call('PUT', '/api/me/password', { token: U, body: { currentPassword: 'wrong', newPassword: 'newpass1' } })).status, 400);
    const ok = await call('PUT', '/api/me/password', { token: U, body: { currentPassword: 'oldpass', newPassword: 'newpass1' } });
    assert.equal(ok.status, 200);
    assert.ok(await bcrypt.compare('newpass1', fakeDb.called(/UPDATE users SET password_hash/)[0].params[0]));
  });

  test('PUT /api/me/password: ไม่พบผู้ใช้ → 400 และฐานข้อมูลล่ม → 500', async () => {
    assert.equal((await call('PUT', '/api/me/password', { token: U, body: { currentPassword: 'a', newPassword: 'newpass1' } })).status, 400);
    fakeDb.fail(/SELECT password_hash AS p/);
    assert.equal((await call('PUT', '/api/me/password', { token: U, body: { currentPassword: 'a', newPassword: 'newpass1' } })).status, 500);
  });
});

test.describe('รีวิวและแจ้งเตือน', () => {
  const booking = (over = {}) =>
    fakeDb.on(/FROM bookings WHERE booking_code = \?/, [[{ booking_id: 5, hotel_id: 1, user_id: 7, status: 'confirmed', check_in_date: future(-2), ...over }]]);
  const review = (body) => call('POST', '/api/reviews', { token: U, body: { bookingCode: 'TN-X', rating: 5, comment: 'ดีมาก', ...body } });

  test('คะแนนต้องอยู่ 1-5', async () => {
    for (const rating of [0, 6, 'x', undefined]) assert.equal((await review({ rating })).status, 400);
  });

  test('ไม่พบการจอง → 404, ของคนอื่น → 403, ยังไม่ยืนยัน → 400, ยังไม่ถึงวันเข้าพัก → 400', async () => {
    assert.equal((await review()).status, 404);
    booking({ user_id: 8 });
    assert.equal((await review()).status, 403);
    booking({ status: 'pending' });
    assert.equal((await review()).status, 400);
    booking({ check_in_date: future(5) });
    assert.equal((await review()).status, 400);
  });

  test('รีวิวสำเร็จ และรีวิวซ้ำ → 409', async () => {
    booking();
    assert.equal((await review()).status, 201);
    assert.deepEqual(fakeDb.called(/INSERT INTO reviews/)[0].params, [5, 7, 1, 5, 'ดีมาก']);
    fakeDb.fail(/INSERT INTO reviews/, Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' }));
    assert.equal((await review()).status, 409);
    fakeDb.fail(/INSERT INTO reviews/);
    assert.equal((await review()).status, 500);
  });

  test('GET /api/hotels/:id/reviews: คืนรายการ จำนวน และค่าเฉลี่ย', async () => {
    fakeDb.on(/FROM reviews r LEFT JOIN users/, [[{ rating: 5, comment: 'ดี', user_name: 'ก' }]]);
    fakeDb.on(/COUNT\(\*\) AS n, AVG\(rating\)/, [[{ n: 2, avg: '4.5' }]]);
    const r = await call('GET', '/api/hotels/1/reviews');
    assert.equal(r.json.count, 2);
    assert.equal(r.json.average, 4.5);
    fakeDb.on(/COUNT\(\*\) AS n, AVG\(rating\)/, [[{ n: 0, avg: null }]]);
    assert.equal((await call('GET', '/api/hotels/1/reviews')).json.average, null);
    fakeDb.fail(/FROM reviews r LEFT JOIN users/);
    assert.equal((await call('GET', '/api/hotels/1/reviews')).status, 500);
  });

  test('แจ้งเตือน: นับที่ยังไม่อ่าน ทำเครื่องหมายอ่านแล้ว และข้อผิดพลาด', async () => {
    fakeDb.on(/FROM notifications WHERE user_id/, [[{ id: 2, is_read: 0 }, { id: 1, is_read: 1 }]]);
    const r = await call('GET', '/api/notifications', { token: U });
    assert.equal(r.json.unread, 1);
    assert.equal((await call('PUT', '/api/notifications/read', { token: U })).status, 200);
    fakeDb.fail(/FROM notifications WHERE user_id/);
    assert.equal((await call('GET', '/api/notifications', { token: U })).status, 500);
    fakeDb.fail(/UPDATE notifications SET is_read/);
    assert.equal((await call('PUT', '/api/notifications/read', { token: U })).status, 500);
  });
});

test.describe('ชำระเงิน', () => {
  const booking = (over = {}) =>
    fakeDb.on(/FROM bookings WHERE booking_code = \?/, [[{ booking_id: 5, user_id: 7, status: 'pending', total_amount: '1500.00', slip_file: null, payment_method: null, paid_at: null, ...over }]]);

  test('payment-info: ไม่พบ 404 / ของคนอื่น 403 / เจ้าของและแอดมินดูได้', async () => {
    assert.equal((await call('GET', '/api/bookings/TN-X/payment-info', { token: U })).status, 404);
    booking({ user_id: 8 });
    assert.equal((await call('GET', '/api/bookings/TN-X/payment-info', { token: U })).status, 403);
    const admin = await call('GET', '/api/bookings/TN-X/payment-info', { token: A });
    assert.equal(admin.status, 200);
    booking({ slip_file: 'a.png' });
    fakeDb.on(/SELECT status FROM payments WHERE booking_id/, [[{ status: 'pending' }]]);
    const r = await call('GET', '/api/bookings/TN-X/payment-info', { token: U });
    assert.equal(r.json.amount, 1500);
    assert.equal(r.json.slipSubmitted, true);
    assert.equal(r.json.paymentStatus, 'pending');
    assert.match(r.json.promptpayPayload, /^000201/);
    assert.equal(r.json.bank.name, 'TestBank');
  });

  test('payment: ต้องเลือกช่องทาง / รายการต้องรอยืนยัน / สลิปต้องเป็นรูป', async () => {
    const pay = (body) => call('POST', '/api/bookings/TN-X/payment', { token: U, body });
    assert.equal((await pay({ method: 'cash' })).status, 400);
    booking({ status: 'confirmed' });
    assert.equal((await pay({ method: 'bank', slip: PNG_BASE64 })).status, 400);
    booking();
    assert.equal((await pay({ method: 'bank', slip: Buffer.from('plain text file').toString('base64') })).status, 400);
    assert.equal((await pay({ method: 'bank' })).status, 400);
  });

  test('payment: ส่งสลิปสำเร็จ เก็บสลิปส่วนตัว บันทึกใน bookings/payments และแจ้งเตือน', async () => {
    booking();
    const r = await call('POST', '/api/bookings/TN-X/payment', { token: U, body: { method: 'promptpay', slip: PNG_BASE64 } });
    assert.equal(r.status, 200);
    const upd = fakeDb.called(/UPDATE bookings SET payment_method/)[0].params;
    assert.equal(upd[0], 'promptpay');
    assert.ok(fs.existsSync(path.join(SLIP_DIR, upd[1])));
    assert.equal(fakeDb.called(/INSERT INTO payments/)[0].params[1], 'QR Payment');
    assert.deepEqual(fakeDb.tx, ['begin', 'commit', 'release']);
    assert.equal(fakeDb.called(/INSERT INTO notifications/).length, 1);
  });

  test('payment: ส่งสลิปซ้ำลบสลิปเก่า / ธนาคาร / ฐานข้อมูลล่ม → ย้อนกลับ', async () => {
    const old = `old-slip-${process.pid}.png`;
    fs.writeFileSync(path.join(SLIP_DIR, old), 'x');
    booking({ slip_file: old });
    const ok = await call('POST', '/api/bookings/TN-X/payment', { token: U, body: { method: 'bank', slip: PNG_BASE64 } });
    assert.equal(ok.status, 200);
    assert.equal(fakeDb.called(/INSERT INTO payments/)[0].params[1], 'Bank Transfer');
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.equal(fs.existsSync(path.join(SLIP_DIR, old)), false);

    fakeDb.fail(/INSERT INTO payments/);
    const bad = await call('POST', '/api/bookings/TN-X/payment', { token: U, body: { method: 'bank', slip: PNG_BASE64 } });
    assert.equal(bad.status, 500);
    assert.ok(fakeDb.tx.includes('rollback'));
  });

  test('slip: ยังไม่มีสลิป 404 / ส่งไฟล์ให้เจ้าของ / คนอื่นเข้าไม่ได้', async () => {
    booking();
    assert.equal((await call('GET', '/api/bookings/TN-X/slip', { token: U })).status, 404);
    const name = `slip-${process.pid}.png`;
    fs.writeFileSync(path.join(SLIP_DIR, name), Buffer.from(PNG_BASE64, 'base64'));
    booking({ slip_file: name });
    const r = await call('GET', '/api/bookings/TN-X/slip', { token: U });
    assert.equal(r.status, 200);
    assert.equal(r.headers.get('cache-control'), 'private, max-age=300');
    assert.equal((await call('GET', '/api/bookings/TN-X/slip', { token: userToken(8) })).status, 403);
    assert.equal((await call('GET', '/api/bookings/TN-X/slip', { token: A })).status, 200);
  });
});

test.describe('แอดมิน: โรงแรม รูป สถิติ', () => {
  test('upload: บันทึกรูปและคืน URL / ไม่ใช่รูป → 400 / ผู้ใช้ทั่วไปใช้ไม่ได้', async () => {
    const ok = await call('POST', '/api/admin/upload', { token: A, body: { data: PNG_BASE64 } });
    assert.equal(ok.status, 201);
    assert.match(ok.json.url, /^\/uploads\/.+\.png$/);
    assert.equal((await call('POST', '/api/admin/upload', { token: A, body: { data: 'aGVsbG8=' } })).status, 400);
    assert.equal((await call('POST', '/api/admin/upload', { token: U, body: { data: PNG_BASE64 } })).status, 403);
  });

  test('PUT /api/admin/hotels/:id: แก้เฉพาะฟิลด์ที่ส่งมา', async () => {
    const put = (body) => call('PUT', '/api/admin/hotels/1', { token: A, body });
    assert.equal((await put({})).status, 400);
    assert.equal((await put({ name: '  ' })).status, 400);
    fakeDb.on(/UPDATE hotels SET/, [{ affectedRows: 0 }]);
    assert.equal((await put({ name: 'ก' })).status, 404);
    fakeDb.on(/UPDATE hotels SET/, [{ affectedRows: 1 }]);
    const r = await put({ name: 'ชื่อ', freeCancelDays: '-4', hasPool: true, hasWifi: 0, imageUrl: null, checkInTime: '15:00:00' });
    assert.equal(r.status, 200);
    const q = fakeDb.called(/UPDATE hotels SET/).at(-1);
    assert.match(q.sql, /name = \?, image_url = \?, free_cancel_days = \?, has_pool = \?, has_wifi = \?, check_in_time = \?/);
    assert.deepEqual(q.params, ['ชื่อ', null, 0, 1, 0, '15:00:00', '1']);
    fakeDb.fail(/UPDATE hotels SET/);
    assert.equal((await put({ name: 'ก' })).status, 500);
  });

  test('DELETE /api/admin/hotels/:id: มีการจอง 409 / ไม่พบ 404 / ลบสำเร็จ / ล่ม 500', async () => {
    const del = () => call('DELETE', '/api/admin/hotels/1', { token: A });
    fakeDb.on(/SELECT COUNT\(\*\) AS n FROM bookings WHERE hotel_id/, [[{ n: 3 }]]);
    assert.equal((await del()).status, 409);
    fakeDb.on(/SELECT COUNT\(\*\) AS n FROM bookings WHERE hotel_id/, [[{ n: 0 }]]);
    fakeDb.on(/DELETE FROM hotels WHERE hotel_id/, [{ affectedRows: 0 }]);
    assert.equal((await del()).status, 404);
    assert.ok(fakeDb.tx.includes('rollback'));
    fakeDb.tx.length = 0;
    fakeDb.on(/DELETE FROM hotels WHERE hotel_id/, [{ affectedRows: 1 }]);
    assert.equal((await del()).status, 200);
    assert.deepEqual(fakeDb.tx, ['begin', 'commit', 'release']);
    fakeDb.fail(/DELETE FROM hotels WHERE hotel_id/);
    assert.equal((await del()).status, 500);
  });

  test('PUT tags: แทนที่ทั้งชุด ตัดซ้ำ/ว่าง และจำกัด 20 แท็ก', async () => {
    const tags = ['ก', ' ก ', '', 'ข', ...Array.from({ length: 30 }, (_, i) => 't' + i)];
    const r = await call('PUT', '/api/admin/hotels/1/tags', { token: A, body: { tags } });
    assert.equal(r.status, 200);
    assert.equal(fakeDb.called(/INSERT INTO hotel_tags/).length, 20);
    assert.equal((await call('PUT', '/api/admin/hotels/1/tags', { token: A, body: { tags: 'x' } })).status, 200);
    fakeDb.fail(/DELETE FROM hotel_tags/);
    assert.equal((await call('PUT', '/api/admin/hotels/1/tags', { token: A, body: { tags: ['ก'] } })).status, 500);
    assert.ok(fakeDb.tx.includes('rollback'));
  });

  test('รูปแกลเลอรี: เพิ่ม (ต้องเป็นรูปที่อัปโหลดแล้ว) ลบ และดูรายการ', async () => {
    assert.equal((await call('POST', '/api/admin/hotels/1/images', { token: A, body: { imageUrl: 'http://evil/x.jpg' } })).status, 400);
    fakeDb.on(/INSERT INTO hotel_images/, [{ insertId: 9 }]);
    const ok = await call('POST', '/api/admin/hotels/1/images', { token: A, body: { imageUrl: '/uploads/a.jpg' } });
    assert.equal(ok.status, 201);
    assert.equal(ok.json.id, 9);
    assert.equal((await call('DELETE', '/api/admin/hotel-images/9', { token: A })).status, 200);
    fakeDb.on(/SELECT id, image_url FROM hotel_images/, [[{ id: 9, image_url: '/uploads/a.jpg' }]]);
    assert.equal((await call('GET', '/api/admin/hotels/1/images', { token: A })).json.data.length, 1);
    fakeDb.fail(/hotel_images/);
    for (const [m, p, b] of [['POST', '/api/admin/hotels/1/images', { imageUrl: '/uploads/a.jpg' }], ['DELETE', '/api/admin/hotel-images/9'], ['GET', '/api/admin/hotels/1/images']]) {
      assert.equal((await call(m, p, { token: A, body: b })).status, 500, `${m} ${p}`);
    }
  });

  test('GET /api/admin/stats: แปลงตัวเลขทั้งหมดเป็น number', async () => {
    fakeDb.on(/COALESCE\(SUM\(status = 'pending'\)/, [[{ total: '10', pending: '2', revenue: '5000.50' }]]);
    fakeDb.on(/COUNT\(\*\) AS n FROM hotels/, [[{ n: 3 }]]);
    fakeDb.on(/COUNT\(\*\) AS n FROM rooms/, [[{ n: 8 }]]);
    fakeDb.on(/COUNT\(\*\) AS n FROM users/, [[{ n: 20 }]]);
    const r = await call('GET', '/api/admin/stats', { token: A });
    assert.deepEqual(r.json.bookings, { total: 10, pending: 2, revenue: 5000.5 });
    assert.deepEqual([r.json.hotels, r.json.rooms, r.json.users], [3, 8, 20]);
    fakeDb.fail(/COUNT\(\*\) AS n FROM users/);
    assert.equal((await call('GET', '/api/admin/stats', { token: A })).status, 500);
  });
});

test.describe('แอดมิน: ยืนยัน/ปฏิเสธการจอง', () => {
  const pending = (over = {}) =>
    fakeDb.on(/status = 'pending' FOR UPDATE/, [[{ booking_id: 5, user_id: 7, room_id: 10, check_in_date: future(3), check_out_date: future(5), num_rooms: 1, ...over }]]);
  const confirm = () => call('PUT', '/api/admin/bookings/TN-X/confirm', { token: A });

  test('ไม่พบ/ไม่ได้รอยืนยัน → 409', async () => {
    assert.equal((await confirm()).status, 409);
    assert.ok(fakeDb.tx.includes('rollback'));
  });

  test('ห้องเต็ม → 409 ไม่ยืนยัน', async () => {
    pending();
    fakeDb.on(/SELECT quantity FROM rooms WHERE room_id/, [[{ quantity: 1 }]]);
    fakeDb.on(/FROM bookings WHERE status IN/, [[{ room_id: 10, check_in_date: future(3), check_out_date: future(5), num_rooms: 1 }]]);
    const r = await confirm();
    assert.equal(r.status, 409);
    assert.match(r.json.message, /ห้องเต็มแล้ว/);
    assert.equal(fakeDb.called(/SET status = 'confirmed'/).length, 0);
  });

  test('ยืนยันสำเร็จ: ตัดห้อง ตั้งการชำระเงินเป็นจ่ายแล้ว และแจ้งลูกค้า', async () => {
    pending();
    fakeDb.on(/SELECT quantity FROM rooms WHERE room_id/, [[{ quantity: 2 }]]);
    assert.equal((await confirm()).status, 200);
    assert.equal(fakeDb.called(/SET status = 'confirmed'/).length, 1);
    assert.equal(fakeDb.called(/UPDATE payments SET status = 'paid'/).length, 1);
    assert.deepEqual(fakeDb.tx, ['begin', 'commit', 'release']);
    assert.equal(fakeDb.called(/INSERT INTO notifications/).length, 1);
  });

  test('ยืนยัน: ไม่มีข้อมูลห้อง → ยืนยันได้, ฐานข้อมูลล่ม → 500', async () => {
    pending();
    assert.equal((await confirm()).status, 200);
    fakeDb.fail(/SET status = 'confirmed'/);
    assert.equal((await confirm()).status, 500);
  });

  test('แอดมินปฏิเสธการจอง: 404 / ยกเลิกแล้ว 400 / สำเร็จพร้อมเหตุผล / ล่ม 500', async () => {
    const cancel = (body) => call('PUT', '/api/admin/bookings/TN-X/cancel', { token: A, body });
    assert.equal((await cancel()).status, 404);
    fakeDb.on(/SELECT booking_id, user_id, status FROM bookings WHERE booking_code/, [[{ booking_id: 5, user_id: 7, status: 'cancelled' }]]);
    assert.equal((await cancel()).status, 400);
    fakeDb.on(/SELECT booking_id, user_id, status FROM bookings WHERE booking_code/, [[{ booking_id: 5, user_id: 7, status: 'pending' }]]);
    assert.equal((await cancel({ reason: 'สลิปไม่ถูกต้อง', details: 'ยอดไม่ตรง' })).status, 200);
    assert.deepEqual(fakeDb.called(/INSERT INTO cancellations/)[0].params, [5, 'สลิปไม่ถูกต้อง', 'ยอดไม่ตรง']);
    assert.equal(fakeDb.called(/UPDATE payments SET status = 'failed'/).length, 1);
    await cancel();
    assert.equal(fakeDb.called(/INSERT INTO cancellations/).at(-1).params[1], 'ยกเลิกโดยผู้ดูแลระบบ');
    fakeDb.fail(/INSERT INTO cancellations/);
    assert.equal((await cancel()).status, 500);
  });
});

test.describe('แอดมิน: ดีล', () => {
  const good = { hotelId: 1, title: 'ลดหน้าฝน', description: 'รายละเอียด', discountPercent: 20, startDate: future(-1), endDate: future(10) };
  const post = (over) => call('POST', '/api/admin/deals', { token: A, body: { ...good, ...over } });

  test('GET: คำนวณสถานะ active / scheduled / expired / off', async () => {
    const d = (id, start, end, active) => ({ deal_id: id, start_date: start, end_date: end, is_active: active });
    fakeDb.on(/FROM deals d LEFT JOIN hotels h/, [[d(1, future(-1), future(1), 1), d(2, future(2), future(5), 1), d(3, future(-9), future(-2), 1), d(4, future(-1), future(1), 0)]]);
    const r = await call('GET', '/api/admin/deals', { token: A });
    assert.deepEqual(r.json.data.map((x) => x.status), ['active', 'scheduled', 'expired', 'off']);
    fakeDb.fail(/FROM deals d LEFT JOIN hotels h/);
    assert.equal((await call('GET', '/api/admin/deals', { token: A })).status, 500);
  });

  test('POST: ตรวจข้อมูลทุกฟิลด์', async () => {
    const cases = [
      { hotelId: undefined },
      { title: ' ' },
      { title: 'ก'.repeat(101) },
      { description: 'ก'.repeat(256) },
      { discountPercent: 0 },
      { discountPercent: 91 },
      { discountPercent: 10.5 },
      { startDate: 'ไม่ใช่วันที่' },
      { startDate: '2026-13-45' },
      { endDate: future(-5) },
    ];
    for (const c of cases) assert.equal((await post(c)).status, 400, JSON.stringify(c));
  });

  test('POST: ไม่พบโรงแรม 404 / สำเร็จ 201 / ล่ม 500', async () => {
    assert.equal((await post()).status, 404);
    fakeDb.on(/SELECT 1 FROM hotels WHERE hotel_id/, [[{ 1: 1 }]]);
    fakeDb.on(/INSERT INTO deals/, [{ insertId: 12 }]);
    const r = await post({ isActive: false });
    assert.equal(r.status, 201);
    assert.equal(r.json.dealId, 12);
    assert.equal(fakeDb.called(/INSERT INTO deals/)[0].params.at(-1), 0);
    fakeDb.fail(/INSERT INTO deals/);
    assert.equal((await post()).status, 500);
  });

  test('PUT: ไม่พบ 404 / แก้บางฟิลด์โดยใช้ค่าเดิมที่เหลือ / ข้อมูลผิด 400 / ล่ม 500', async () => {
    const put = (body) => call('PUT', '/api/admin/deals/3', { token: A, body });
    assert.equal((await put({})).status, 404);
    fakeDb.on(/FROM deals d LEFT JOIN hotels h ON h\.hotel_id = d\.hotel_id\s+WHERE d\.deal_id/, [[{ deal_id: 3, hotel_id: 1, title: 'เดิม', description: null, discount_percent: 15, start_date: future(-1), end_date: future(5), is_active: 1 }]]);
    assert.equal((await put({ discountPercent: 99 })).status, 400);
    assert.equal((await put({ discountPercent: 30 })).status, 404); // ไม่พบโรงแรม
    fakeDb.on(/SELECT 1 FROM hotels WHERE hotel_id/, [[{ 1: 1 }]]);
    assert.equal((await put({ discountPercent: 30, isActive: false })).status, 200);
    const p = fakeDb.called(/UPDATE deals SET/)[0].params;
    assert.deepEqual([p[1], p[2], p[3], p[6], p[7]], ['เดิม', null, 30, 0, '3']);
    fakeDb.fail(/UPDATE deals SET/);
    assert.equal((await put({ title: 'ใหม่' })).status, 500);
  });

  test('DELETE: 404 / สำเร็จ / ล่ม 500', async () => {
    const del = () => call('DELETE', '/api/admin/deals/3', { token: A });
    fakeDb.on(/DELETE FROM deals/, [{ affectedRows: 0 }]);
    assert.equal((await del()).status, 404);
    fakeDb.on(/DELETE FROM deals/, [{ affectedRows: 1 }]);
    assert.equal((await del()).status, 200);
    fakeDb.fail(/DELETE FROM deals/);
    assert.equal((await del()).status, 500);
  });
});

test.describe('แอดมิน: ห้องพัก', () => {
  test('GET /api/admin/rooms: คำนวณห้องที่ใช้/รอยืนยัน/ว่าง ตามคืนที่เลือก และกรองตามโรงแรม', async () => {
    fakeDb.on(/FROM rooms r LEFT JOIN hotels h/, [[{ room_id: 10, hotel_id: 1, hotel_name: 'A', room_type: 'Deluxe', price_per_night: 1000, quantity: 5, max_guests: 2 }]]);
    fakeDb.on(/FROM bookings WHERE status IN/, (params) =>
      params[0].includes('pending') ? [[{ room_id: 10, check_in_date: '2030-05-01', check_out_date: '2030-05-02', num_rooms: 1 }]] : [[{ room_id: 10, check_in_date: '2030-05-01', check_out_date: '2030-05-03', num_rooms: 2 }]]
    );
    const r = await call('GET', '/api/admin/rooms?hotelId=1&date=2030-05-01', { token: A });
    assert.equal(r.status, 200);
    const room = r.json.data[0];
    assert.equal(room.name, 'Deluxe');
    assert.equal(room.booked_tonight, 2);
    assert.equal(room.pending_tonight, 1);
    assert.equal(room.rooms_available, 3);
    assert.equal(room.night, '2030-05-01');
    assert.match(fakeDb.called(/FROM rooms r LEFT JOIN hotels h/)[0].sql, /WHERE r\.hotel_id = \?/);
    fakeDb.fail(/FROM rooms r LEFT JOIN hotels h/);
    assert.equal((await call('GET', '/api/admin/rooms', { token: A })).status, 500);
  });

  test('POST /api/admin/rooms: ตรวจข้อมูล / เพิ่มห้อง / ล่ม', async () => {
    const post = (body) => call('POST', '/api/admin/rooms', { token: A, body });
    for (const b of [{}, { hotelId: 1, name: 'x' }, { hotelId: 1, name: 'x', price: -5 }]) assert.equal((await post(b)).status, 400);
    fakeDb.on(/INSERT INTO rooms/, [{ insertId: 31 }]);
    const r = await post({ hotelId: 1, name: ' Suite ', price: 2500, quantity: '0', maxGuests: '3', bedType: ' King ', sizeSqm: '', imageUrl: '/uploads/r.jpg' });
    assert.equal(r.status, 201);
    assert.equal(r.json.roomId, 31);
    const q = fakeDb.called(/INSERT INTO rooms/)[0];
    assert.match(q.sql, /hotel_id, price_per_night, quantity, max_guests, bed_type, size_sqm, image_url, room_type/);
    assert.deepEqual(q.params, [1, 2500, 1, 3, 'King', null, '/uploads/r.jpg', 'Suite']);
    fakeDb.fail(/INSERT INTO rooms/);
    assert.equal((await post({ hotelId: 1, name: 'x', price: 1 })).status, 500);
  });

  test('PUT /api/admin/rooms/:id/quantity: ตรวจค่า / ไม่พบ / ลดต่ำกว่าที่จองไม่ได้ / ปรับสำเร็จ', async () => {
    const put = (body) => call('PUT', '/api/admin/rooms/10/quantity', { token: A, body });
    assert.equal((await put({})).status, 400);
    assert.equal((await put({ quantity: 'x' })).status, 400);
    assert.equal((await put({ delta: 1 })).status, 404);
    fakeDb.on(/SELECT quantity FROM rooms WHERE room_id/, [[{ quantity: 4 }]]);
    fakeDb.on(/FROM bookings WHERE status IN/, [[{ room_id: 10, check_in_date: todayStr(), check_out_date: future(3), num_rooms: 3 }]]);
    const tooLow = await put({ delta: -2 });
    assert.equal(tooLow.status, 409);
    assert.match(tooLow.json.message, /อย่างน้อย 3/);
    const ok = await put({ delta: 1 });
    assert.equal(ok.status, 200);
    assert.equal(ok.json.quantity, 5);
    assert.equal(ok.json.booked_tonight, 3);
    assert.equal(ok.json.rooms_available, 2);
    assert.equal((await put({ quantity: 99999 })).json.quantity, 9999);
    fakeDb.fail(/UPDATE rooms SET quantity/);
    assert.equal((await put({ delta: 1 })).status, 500);
  });

  test('PUT /api/admin/rooms/:id: ไม่มีข้อมูล 400 / ไม่พบ 404 / แก้สำเร็จ / ล่ม 500', async () => {
    const put = (body) => call('PUT', '/api/admin/rooms/10', { token: A, body });
    assert.equal((await put({})).status, 400);
    fakeDb.on(/UPDATE rooms SET/, [{ affectedRows: 0 }]);
    assert.equal((await put({ price: 900 })).status, 404);
    fakeDb.on(/UPDATE rooms SET/, [{ affectedRows: 1 }]);
    assert.equal((await put({ price: 900, name: ' ห้องใหม่ ', quantity: 3 })).status, 200);
    const q = fakeDb.called(/UPDATE rooms SET/).at(-1);
    assert.deepEqual(q.params, [3, 900, 'ห้องใหม่', '10']);
    fakeDb.fail(/UPDATE rooms SET/);
    assert.equal((await put({ price: 1 })).status, 500);
  });
});
