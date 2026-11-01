const { fakeDb } = require('./support/env');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const h = require('../helpers');

test.beforeEach(() => fakeDb.reset());

const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(16)]);
const JPG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(16)]);
const GIF = Buffer.concat([Buffer.from('GIF89a'), Buffer.alloc(16)]);
const WEBP = Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WEBP'), Buffer.alloc(8)]);

test.describe('วันที่', () => {
  test('addDays บวก/ลบวัน และข้ามเดือน/ปี', () => {
    assert.equal(h.addDays('2026-01-31', 1), '2026-02-01');
    assert.equal(h.addDays('2026-12-31', 1), '2027-01-01');
    assert.equal(h.addDays('2026-03-01', -1), '2026-02-28');
    assert.equal(h.addDays('2024-02-28', 1), '2024-02-29');
  });

  test('todayStr คืนรูปแบบ YYYY-MM-DD', () => {
    assert.match(h.todayStr(), /^\d{4}-\d{2}-\d{2}$/);
  });

  test('stayRange ใช้ค่าที่ส่งมา ถ้าถูกต้องและเป็นอนาคต', () => {
    const from = h.addDays(h.todayStr(), 5);
    const to = h.addDays(from, 3);
    assert.deepEqual(h.stayRange({ checkIn: from, checkOut: to }), { from, to });
  });

  test('stayRange ถ้าไม่ระบุ/ผิดรูปแบบ ใช้ "คืนนี้"', () => {
    const today = h.todayStr();
    const tomorrow = h.addDays(today, 1);
    assert.deepEqual(h.stayRange(undefined), { from: today, to: tomorrow });
    assert.deepEqual(h.stayRange({ checkIn: 'abc', checkOut: '12/01/2026' }), { from: today, to: tomorrow });
  });

  test('stayRange เลื่อนวันเช็คอินในอดีตเป็นวันนี้ และแก้ checkOut ที่ไม่เกิน checkIn', () => {
    const today = h.todayStr();
    const r = h.stayRange({ checkIn: '2000-01-01', checkOut: '2000-01-05' });
    assert.equal(r.from, today);
    assert.equal(r.to, h.addDays(today, 1));
    const from = h.addDays(today, 2);
    assert.equal(h.stayRange({ checkIn: from, checkOut: from }).to, h.addDays(from, 1));
  });
});

test.describe('ส่วนลด/ดีล', () => {
  test('discounted ปัดเศษ 2 ตำแหน่ง', () => {
    assert.equal(h.discounted(1000, 10), 900);
    assert.equal(h.discounted('1999', 15), 1699.15);
    assert.equal(h.discounted(500, 0), 500);
    assert.equal(h.discounted(500, 100), 0);
  });

  test('dealView คืนเฉพาะข้อมูลที่แอปใช้', () => {
    const v = h.dealView({ deal_id: 3, title: 'ลดหน้าฝน', description: null, discount_percent: '12.50', end_date: '2026-09-30 00:00:00', secret: 'x' });
    assert.deepEqual(v, { deal_id: 3, title: 'ลดหน้าฝน', description: '', discount_percent: 12.5, end_date: '2026-09-30' });
  });

  test('activeDealsByHotel เลือกดีลที่ลดมากสุดของแต่ละโรงแรม', async () => {
    fakeDb.handler = () => [[
      { deal_id: 1, hotel_id: 10, discount_percent: 30 },
      { deal_id: 2, hotel_id: 10, discount_percent: 10 },
      { deal_id: 3, hotel_id: 11, discount_percent: 5 },
    ]];
    const map = await h.activeDealsByHotel(fakeDb);
    assert.equal(map.size, 2);
    assert.equal(map.get(10).deal_id, 1);
    assert.equal(map.get(11).deal_id, 3);
    assert.ok(!fakeDb.calls[0].sql.includes('hotel_id = ?'));
  });

  test('activeDealsByHotel กรองตามโรงแรมเมื่อระบุ hotelId', async () => {
    await h.activeDealsByHotel(fakeDb, 7);
    const call = fakeDb.calls[0];
    assert.ok(call.sql.includes('AND hotel_id = ?'));
    assert.equal(call.params.at(-1), 7);
  });
});

test.describe('peakBookedByRoom', () => {
  test('ไม่มีรายการห้องให้ดู → Map ว่าง โดยไม่ query', async () => {
    const m = await h.peakBookedByRoom(fakeDb, '2026-06-01', '2026-06-03', []);
    assert.equal(m.size, 0);
    assert.equal(fakeDb.calls.length, 0);
  });

  test('นับจำนวนห้องที่ถูกจองพร้อมกันสูงสุด', async () => {
    fakeDb.handler = () => [[
      { room_id: 1, check_in_date: '2026-06-01', check_out_date: '2026-06-03', num_rooms: 2 },
      { room_id: 1, check_in_date: '2026-06-02', check_out_date: '2026-06-04', num_rooms: 1 },
      { room_id: 2, check_in_date: '2026-06-01', check_out_date: '2026-06-02', num_rooms: null },
    ]];
    const m = await h.peakBookedByRoom(fakeDb, '2026-06-01', '2026-06-05');
    assert.equal(m.get(1), 3); // คืนวันที่ 2 ซ้อนกัน 2 + 1
    assert.equal(m.get(2), 1); // num_rooms ว่างถือเป็น 1
    assert.equal(m.get(99), undefined);
  });

  test('ส่ง roomIds และ statuses ไปยัง SQL', async () => {
    await h.peakBookedByRoom(fakeDb, '2026-06-01', '2026-06-02', [4, 5], ['pending']);
    const { sql, params } = fakeDb.calls[0];
    assert.ok(sql.includes('room_id IN (?)'));
    assert.deepEqual(params, [['pending'], '2026-06-02', '2026-06-01', [4, 5]]);
  });
});

test.describe('PromptPay', () => {
  function crc(str) {
    let c = 0xffff;
    for (const b of Buffer.from(str)) {
      c ^= b << 8;
      for (let i = 0; i < 8; i++) c = c & 0x8000 ? (c << 1) ^ 0x1021 : c << 1;
      c &= 0xffff;
    }
    return c.toString(16).toUpperCase().padStart(4, '0');
  }

  test('เบอร์มือถือ + ยอดเงิน: โครงสร้างและ CRC ถูกต้อง', () => {
    const p = h.promptpayPayload('081-234-5678', 1500);
    assert.ok(p.startsWith('000201010212'));
    assert.ok(p.includes('0066812345678'));
    assert.ok(p.includes('54071500.00'));
    assert.ok(p.includes('5802TH'));
    assert.equal(p.slice(-4), crc(p.slice(0, -4)));
  });

  test('ไม่ระบุยอด ใช้ QR แบบใช้ซ้ำได้ (11)', () => {
    const p = h.promptpayPayload('0812345678');
    assert.ok(p.startsWith('000201010211'));
    assert.ok(!p.includes('5407'));
  });

  test('เลขบัตรประชาชน 13 หลักใช้ tag 02', () => {
    const p = h.promptpayPayload('1234567890123', 10);
    assert.ok(p.includes('02131234567890123'));
  });

  test('ไม่มีเลขรับเงิน → null', () => {
    assert.equal(h.promptpayPayload('', 100), null);
    assert.equal(h.promptpayPayload(null, 100), null);
  });
});

test.describe('saveImage', () => {
  let dir;
  test.before(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'teenon-img-')); });
  test.after(() => fs.rmSync(dir, { recursive: true, force: true }));

  for (const [name, buf] of [['png', PNG], ['jpg', JPG], ['gif', GIF], ['webp', WEBP]]) {
    test(`บันทึกไฟล์ ${name} ตามชนิดจริงของไฟล์`, async () => {
      const file = await h.saveImage(dir, 'data:image/x;base64,' + buf.toString('base64'));
      assert.ok(file.endsWith('.' + name));
      assert.deepEqual(fs.readFileSync(path.join(dir, file)), buf);
    });
  }

  test('ไม่เชื่อนามสกุลที่ client ส่งมา: ไฟล์ที่ไม่ใช่รูปถูกปฏิเสธ', async () => {
    const bad = Buffer.from('<?php echo 1; ?> padding padding').toString('base64');
    await assert.rejects(h.saveImage(dir, bad), (e) => e.status === 400 && /jpg, png, webp, gif/.test(e.message));
  });

  test('ไม่มีข้อมูล → 400', async () => {
    await assert.rejects(h.saveImage(dir, ''), (e) => e.status === 400);
    await assert.rejects(h.saveImage(dir, undefined), (e) => e.status === 400);
  });

  test('ไฟล์ใหญ่เกิน 6 MB → 400', async () => {
    const big = Buffer.concat([PNG, Buffer.alloc(6 * 1024 * 1024)]).toString('base64');
    await assert.rejects(h.saveImage(dir, big), (e) => e.status === 400 && /6 MB/.test(e.message));
  });
});

test.describe('ฐานข้อมูลช่วยเหลือ', () => {
  test('ensureColumn เพิ่มคอลัมน์เมื่อยังไม่มี', async () => {
    fakeDb.handler = (sql) => (sql.startsWith('SHOW') ? [[]] : [{}]);
    await h.ensureColumn('hotels', 'foo', 'INT NULL');
    assert.equal(fakeDb.calls.length, 2);
    assert.match(fakeDb.calls[1].sql, /ALTER TABLE hotels ADD COLUMN foo INT NULL/);
  });

  test('ensureColumn ไม่ทำอะไรถ้ามีคอลัมน์อยู่แล้ว', async () => {
    fakeDb.handler = () => [[{ Field: 'foo' }]];
    await h.ensureColumn('hotels', 'foo', 'INT NULL');
    assert.equal(fakeDb.calls.length, 1);
  });

  test('notify บันทึกแจ้งเตือน และกลืน error ไม่ให้กระทบงานหลัก', async () => {
    await h.notify(5, 'หัวข้อ', 'เนื้อหา');
    assert.deepEqual(fakeDb.calls[0].params, [5, 'หัวข้อ', 'เนื้อหา']);
    fakeDb.handler = () => { throw new Error('db down'); };
    const orig = console.error;
    console.error = () => {};
    try {
      await assert.doesNotReject(h.notify(5, 'x', 'y'));
    } finally {
      console.error = orig;
    }
  });

  test('sendMail ถ้ายังไม่ตั้ง SMTP แสดงข้อความใน Terminal แทนการส่ง', async () => {
    const orig = console.warn;
    const logged = [];
    console.warn = (m) => logged.push(m);
    try {
      await h.sendMail('a@b.com', 'หัวเรื่อง', 'ข้อความ');
    } finally {
      console.warn = orig;
    }
    assert.equal(logged.length, 1);
    assert.match(logged[0], /a@b\.com/);
  });
});
