// ไฟล์ features.js — ฟีเจอร์เสริมของ API: โปรไฟล์ รีวิว แจ้งเตือน ชำระเงิน และเครื่องมือแอดมิน
// เรียกใช้จาก server.js: require('./features')(app, { ...ตัวช่วยจาก server.js })
const fs = require('fs');
const path = require('path');
const db = require('./db');
const { UPLOAD_DIR, SLIP_DIR, saveImage, ensureColumn, notify, todayStr, addDays, peakBookedByRoom, promptpayPayload } = require('./helpers');

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

// ===== ปรับโครงสร้างฐานข้อมูลอัตโนมัติ (ฐานข้อมูลเดิมใช้ต่อได้โดยไม่ต้องรัน SQL เอง) =====
async function migrate() {
  try {
    // รายละเอียดห้อง: จำนวนห้องที่มี (ใช้ตรวจห้องว่าง), จำนวนผู้เข้าพักสูงสุด, ประเภทเตียง, ขนาด
    await ensureColumn('rooms', 'quantity', 'INT NOT NULL DEFAULT 5');
    await ensureColumn('rooms', 'max_guests', 'INT NULL');
    await ensureColumn('rooms', 'bed_type', 'VARCHAR(50) NULL');
    await ensureColumn('rooms', 'size_sqm', 'INT NULL');
    // นโยบายยกเลิกของโรงแรม
    await ensureColumn('hotels', 'cancellation_policy', 'VARCHAR(255) NULL');
    await ensureColumn('hotels', 'free_cancel_days', 'INT NOT NULL DEFAULT 3');
    // การชำระเงิน
    await ensureColumn('bookings', 'payment_method', 'VARCHAR(30) NULL');
    await ensureColumn('bookings', 'slip_file', 'VARCHAR(255) NULL');
    await ensureColumn('bookings', 'paid_at', 'DATETIME NULL');

    await db.query(`
      CREATE TABLE IF NOT EXISTS reviews (
        review_id INT AUTO_INCREMENT PRIMARY KEY,
        booking_id INT NOT NULL UNIQUE,
        user_id INT NOT NULL,
        hotel_id INT NOT NULL,
        rating TINYINT NOT NULL,
        comment TEXT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_reviews_hotel (hotel_id)
      )
    `);
    await db.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        title VARCHAR(150) NOT NULL,
        body VARCHAR(500) NOT NULL,
        is_read TINYINT(1) NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_notifications_user (user_id)
      )
    `);
    // ดีล/โปรโมชัน: ส่วนลด % ของโรงแรม ในช่วงวันที่ที่กำหนด (ใช้กับทุกประเภทห้องของโรงแรมนั้น)
    await db.query(`
      CREATE TABLE IF NOT EXISTS deals (
        deal_id INT AUTO_INCREMENT PRIMARY KEY,
        hotel_id INT NOT NULL,
        title VARCHAR(100) NOT NULL,
        description VARCHAR(255) NULL,
        discount_percent TINYINT UNSIGNED NOT NULL,
        start_date DATE NOT NULL,
        end_date DATE NOT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_deals_hotel (hotel_id),
        FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE
      )
    `);
    // การจองที่ใช้ดีล: เก็บดีลที่ใช้และจำนวนเงินที่ลด
    await ensureColumn('bookings', 'deal_id', 'INT NULL');
    await ensureColumn('bookings', 'discount_amount', 'DECIMAL(10,2) NOT NULL DEFAULT 0');
    // รูปโปรไฟล์ของผู้ใช้ (path เช่น /uploads/avatars/xxx.jpg)
    await ensureColumn('users', 'avatar_url', 'VARCHAR(255) NULL');
    // บันทึกการชำระเงิน 1 รายการต่อ 1 การจอง (ตารางนี้มีในฐานข้อมูลเดิมอยู่แล้ว คำสั่งนี้ไม่แตะถ้ามีแล้ว)
    await db.query(`
      CREATE TABLE IF NOT EXISTS payments (
        payment_id INT AUTO_INCREMENT PRIMARY KEY,
        booking_id INT NOT NULL,
        payment_method ENUM('QR Payment','Credit / Debit Card','Bank Transfer') NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        slip_url VARCHAR(255) DEFAULT NULL,
        status ENUM('pending','paid','failed') DEFAULT 'paid',
        paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY booking_id (booking_id),
        FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
      )
    `);
    // ย้ายข้อมูลชำระเงินเดิมที่เก็บไว้ในตาราง bookings (มีสลิปแล้ว) เข้า payments — ทำซ้ำได้ ไม่ซ้ำแถว
    await db.query(`
      INSERT IGNORE INTO payments (booking_id, payment_method, amount, slip_url, status, paid_at)
      SELECT booking_id,
             CASE payment_method WHEN 'bank' THEN 'Bank Transfer' ELSE 'QR Payment' END,
             total_amount,
             CONCAT('/api/bookings/', booking_code, '/slip'),
             CASE status WHEN 'confirmed' THEN 'paid' WHEN 'completed' THEN 'paid' WHEN 'cancelled' THEN 'failed' ELSE 'pending' END,
             COALESCE(paid_at, NOW())
      FROM bookings
      WHERE slip_file IS NOT NULL AND payment_method IS NOT NULL
    `);
    await db.query(`
      CREATE TABLE IF NOT EXISTS hotel_images (
        id INT AUTO_INCREMENT PRIMARY KEY,
        hotel_id INT NOT NULL,
        image_url VARCHAR(255) NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_hotel_images_hotel (hotel_id)
      )
    `);
  } catch (e) {
    console.error('ปรับโครงสร้างฐานข้อมูลไม่สำเร็จ:', e.message);
  }
}

// ยกเลิกอัตโนมัติ: การจองที่ยังไม่ส่งสลิปเกินเวลาที่กำหนด (UNPAID_EXPIRE_HOURS ชั่วโมง, ค่าเริ่มต้น 24) เพื่อคืนห้องให้คนอื่นจอง
async function expireUnpaidBookings() {
  const hours = Math.max(1, Number(process.env.UNPAID_EXPIRE_HOURS) || 24);
  try {
    const [rows] = await db.query(
      "SELECT booking_id, booking_code, user_id FROM bookings WHERE status = 'pending' AND slip_file IS NULL AND created_at < (NOW() - INTERVAL ? HOUR)",
      [hours]
    );
    for (const b of rows) {
      const [r] = await db.query("UPDATE bookings SET status = 'cancelled' WHERE booking_id = ? AND status = 'pending' AND slip_file IS NULL", [b.booking_id]);
      if (r.affectedRows === 0) continue;
      await db.query('INSERT INTO cancellations (booking_id, reason, additional_details, cancelled_at) VALUES (?, ?, ?, NOW())', [
        b.booking_id,
        'ไม่ได้ชำระเงินตามกำหนด',
        `ยกเลิกอัตโนมัติ เพราะไม่ส่งสลิปภายใน ${hours} ชั่วโมง`,
      ]);
      await notify(b.user_id, 'การจองถูกยกเลิก', `การจอง ${b.booking_code} ถูกยกเลิกอัตโนมัติ เพราะไม่ได้ชำระเงินภายใน ${hours} ชั่วโมง`);
    }
  } catch (e) {
    console.error('ยกเลิกการจองที่ไม่ชำระเงินไม่สำเร็จ:', e.message);
  }
}

module.exports = function registerFeatures(app, { authenticate, requireAdmin, errText, userCols, bcrypt }) {
  void migrate();
  void expireUnpaidBookings();
  setInterval(expireUnpaidBookings, 10 * 60 * 1000).unref();

  const fail = (res, error) => {
    if (error && error.status) return res.status(error.status).json({ success: false, message: error.message });
    return res.status(500).json({ success: false, message: errText(error) });
  };

  // ข้อมูลติดต่อและค่าแสดงผลของแอป (ตั้งใน .env)
  app.get('/api/config', (req, res) => {
    res.json({
      success: true,
      contact: {
        phone: process.env.CONTACT_PHONE || '',
        line: process.env.CONTACT_LINE || '',
        email: process.env.CONTACT_EMAIL || '',
        hours: process.env.CONTACT_HOURS || '',
      },
    });
  });

  // ===== โปรไฟล์ของฉัน =====
  app.put('/api/me', authenticate, async (req, res) => {
    const name = String(req.body?.name ?? '').trim();
    const phone = String(req.body?.phone ?? '').trim();
    if (!name) return res.status(400).json({ success: false, message: 'กรอกชื่อ' });
    if (phone && !/^[0-9+\-\s]{8,20}$/.test(phone)) {
      return res.status(400).json({ success: false, message: 'เบอร์โทรไม่ถูกต้อง' });
    }
    try {
      const c = await userCols();
      const sets = [];
      const vals = [];
      if (c.name) { sets.push(`${c.name} = ?`); vals.push(name); }
      if (c.phone) { sets.push(`${c.phone} = ?`); vals.push(phone); }
      if (sets.length === 0) return res.status(400).json({ success: false, message: 'ตารางผู้ใช้ไม่มีคอลัมน์ให้แก้ไข' });
      await db.query(`UPDATE users SET ${sets.join(', ')} WHERE ${c.id} = ?`, [...vals, req.user.id]);
      const [rows] = await db.query(`SELECT * FROM users WHERE ${c.id} = ? LIMIT 1`, [req.user.id]);
      const r = rows[0];
      res.json({
        success: true,
        user: { id: r[c.id], name: c.name ? r[c.name] : '', email: r[c.email], phone: c.phone ? r[c.phone] || '' : '', role: r[c.role] || 'user', avatar: r.avatar_url || '' },
      });
    } catch (error) {
      fail(res, error);
    }
  });

  // ===== รูปโปรไฟล์ =====
  const AVATAR_DIR = path.join(UPLOAD_DIR, 'avatars');
  fs.mkdirSync(AVATAR_DIR, { recursive: true });
  const dropAvatarFile = (url) => {
    // ลบเฉพาะไฟล์ในโฟลเดอร์ avatars (ไม่แตะรูปโรงแรม/ห้อง)
    if (String(url || '').startsWith('/uploads/avatars/')) fs.promises.unlink(path.join(AVATAR_DIR, path.basename(url))).catch(() => {});
  };

  // ส่ง { data: <base64> } → เปลี่ยนรูปโปรไฟล์ คืน { avatar: '/uploads/avatars/xxx.jpg' }
  app.put('/api/me/avatar', authenticate, async (req, res) => {
    try {
      const c = await userCols();
      const [rows] = await db.query(`SELECT avatar_url FROM users WHERE ${c.id} = ? LIMIT 1`, [req.user.id]);
      if (rows.length === 0) return res.status(404).json({ success: false, message: 'ไม่พบผู้ใช้' });
      const file = await saveImage(AVATAR_DIR, req.body?.data);
      const url = `/uploads/avatars/${file}`;
      await db.query(`UPDATE users SET avatar_url = ? WHERE ${c.id} = ?`, [url, req.user.id]);
      dropAvatarFile(rows[0].avatar_url);
      res.json({ success: true, avatar: url });
    } catch (error) {
      fail(res, error);
    }
  });

  app.delete('/api/me/avatar', authenticate, async (req, res) => {
    try {
      const c = await userCols();
      const [rows] = await db.query(`SELECT avatar_url FROM users WHERE ${c.id} = ? LIMIT 1`, [req.user.id]);
      await db.query(`UPDATE users SET avatar_url = NULL WHERE ${c.id} = ?`, [req.user.id]);
      if (rows[0]) dropAvatarFile(rows[0].avatar_url);
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  app.put('/api/me/password', authenticate, async (req, res) => {
    const current = String(req.body?.currentPassword || '');
    const next = String(req.body?.newPassword || '');
    if (next.length < 6) return res.status(400).json({ success: false, message: 'รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร' });
    try {
      const c = await userCols();
      const [rows] = await db.query(`SELECT ${c.pass} AS p FROM users WHERE ${c.id} = ? LIMIT 1`, [req.user.id]);
      if (!rows[0] || !(await bcrypt.compare(current, String(rows[0].p || '')))) {
        return res.status(400).json({ success: false, message: 'รหัสผ่านปัจจุบันไม่ถูกต้อง' });
      }
      await db.query(`UPDATE users SET ${c.pass} = ? WHERE ${c.id} = ?`, [await bcrypt.hash(next, 10), req.user.id]);
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  // ===== รีวิว =====
  app.post('/api/reviews', authenticate, async (req, res) => {
    const code = String(req.body?.bookingCode || '');
    const rating = Number.parseInt(req.body?.rating, 10);
    const comment = String(req.body?.comment || '').trim().slice(0, 2000);
    if (!(rating >= 1 && rating <= 5)) return res.status(400).json({ success: false, message: 'ให้คะแนน 1-5 ดาว' });
    try {
      const [rows] = await db.query(
        'SELECT booking_id, hotel_id, user_id, status, check_in_date FROM bookings WHERE booking_code = ?',
        [code]
      );
      const b = rows[0];
      if (!b) return res.status(404).json({ success: false, message: 'ไม่พบรายการจองนี้' });
      if (Number(b.user_id) !== Number(req.user.id)) {
        return res.status(403).json({ success: false, message: 'รีวิวได้เฉพาะการจองของตัวเอง' });
      }
      if (b.status !== 'confirmed' && b.status !== 'completed') {
        return res.status(400).json({ success: false, message: 'รีวิวได้เมื่อการจองได้รับการยืนยันแล้ว' });
      }
      if (String(b.check_in_date).slice(0, 10) > todayStr()) {
        return res.status(400).json({ success: false, message: 'รีวิวได้หลังถึงวันเข้าพัก' });
      }
      await db.query('INSERT INTO reviews (booking_id, user_id, hotel_id, rating, comment) VALUES (?, ?, ?, ?, ?)', [
        b.booking_id, req.user.id, b.hotel_id, rating, comment || null,
      ]);
      res.status(201).json({ success: true });
    } catch (error) {
      if (error && error.code === 'ER_DUP_ENTRY') {
        return res.status(409).json({ success: false, message: 'คุณรีวิวการจองนี้แล้ว' });
      }
      fail(res, error);
    }
  });

  app.get('/api/hotels/:id/reviews', async (req, res) => {
    try {
      const c = await userCols();
      const [rows] = await db.query(
        `SELECT r.rating, r.comment, r.created_at, ${c.name ? 'u.' + c.name : 'NULL'} AS user_name
         FROM reviews r LEFT JOIN users u ON u.${c.id} = r.user_id
         WHERE r.hotel_id = ? ORDER BY r.review_id DESC LIMIT 50`,
        [req.params.id]
      );
      const [[sum]] = await db.query('SELECT COUNT(*) AS n, AVG(rating) AS avg FROM reviews WHERE hotel_id = ?', [req.params.id]);
      res.json({ success: true, count: Number(sum.n), average: sum.avg == null ? null : Number(sum.avg), data: rows });
    } catch (error) {
      fail(res, error);
    }
  });

  // ===== แจ้งเตือน =====
  app.get('/api/notifications', authenticate, async (req, res) => {
    try {
      const [rows] = await db.query(
        'SELECT id, title, body, is_read, created_at FROM notifications WHERE user_id = ? ORDER BY id DESC LIMIT 50',
        [req.user.id]
      );
      res.json({ success: true, unread: rows.filter((r) => !r.is_read).length, data: rows });
    } catch (error) {
      fail(res, error);
    }
  });

  app.put('/api/notifications/read', authenticate, async (req, res) => {
    try {
      await db.query('UPDATE notifications SET is_read = 1 WHERE user_id = ?', [req.user.id]);
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  // ===== ชำระเงิน =====
  async function ownedBooking(code, user) {
    const [rows] = await db.query(
      'SELECT booking_id, user_id, status, total_amount, slip_file, payment_method, paid_at FROM bookings WHERE booking_code = ?',
      [code]
    );
    const b = rows[0];
    if (!b) throw Object.assign(new Error('ไม่พบรายการจองนี้'), { status: 404 });
    if (user.role !== 'admin' && Number(b.user_id) !== Number(user.id)) {
      throw Object.assign(new Error('ไม่มีสิทธิ์เข้าถึงรายการนี้'), { status: 403 });
    }
    return b;
  }

  // ข้อมูลสำหรับหน้าชำระเงิน: ยอด + PromptPay QR + บัญชีธนาคาร (ตั้งค่าใน .env)
  app.get('/api/bookings/:code/payment-info', authenticate, async (req, res) => {
    try {
      const b = await ownedBooking(req.params.code, req.user);
      const amount = Number(b.total_amount);
      res.json({
        success: true,
        amount,
        status: b.status,
        paymentMethod: b.payment_method,
        paidAt: b.paid_at,
        slipSubmitted: Boolean(b.slip_file),
        paymentStatus: (await db.query('SELECT status FROM payments WHERE booking_id = ?', [b.booking_id]))[0][0]?.status || null,
        promptpayPayload: promptpayPayload(process.env.PROMPTPAY_ID, amount),
        bank: {
          name: process.env.BANK_NAME || '',
          accountNo: process.env.BANK_ACCOUNT_NO || '',
          accountName: process.env.BANK_ACCOUNT_NAME || '',
        },
      });
    } catch (error) {
      fail(res, error);
    }
  });

  // ส่งสลิปการโอน (ต้องแนบสลิปทุกครั้ง) แล้วรอแอดมินตรวจและกดยืนยัน
  app.post('/api/bookings/:code/payment', authenticate, async (req, res) => {
    const method = String(req.body?.method || '');
    if (!['promptpay', 'bank'].includes(method)) {
      return res.status(400).json({ success: false, message: 'เลือกช่องทางชำระเงิน' });
    }
    try {
      const b = await ownedBooking(req.params.code, req.user);
      if (b.status !== 'pending') {
        return res.status(400).json({ success: false, message: 'รายการนี้ไม่ได้อยู่ในสถานะรอยืนยัน' });
      }
      const file = await saveImage(SLIP_DIR, req.body?.slip);
      if (b.slip_file) fs.promises.unlink(path.join(SLIP_DIR, path.basename(b.slip_file))).catch(() => {});
      // บันทึกทั้งในตาราง bookings (ใช้แสดงผลเร็ว) และตาราง payments (ประวัติการชำระเงิน 1 รายการต่อการจอง)
      // ส่งสลิปซ้ำ = อัปเดตแถวเดิม และกลับไปรอตรวจใหม่
      const conn = await db.getConnection();
      try {
        await conn.beginTransaction();
        await conn.query('UPDATE bookings SET payment_method = ?, slip_file = ?, paid_at = NOW() WHERE booking_id = ?', [method, file, b.booking_id]);
        await conn.query(
          `INSERT INTO payments (booking_id, payment_method, amount, slip_url, status, paid_at) VALUES (?, ?, ?, ?, 'pending', NOW())
           ON DUPLICATE KEY UPDATE payment_method = VALUES(payment_method), amount = VALUES(amount), slip_url = VALUES(slip_url), status = 'pending', paid_at = NOW()`,
          [b.booking_id, method === 'bank' ? 'Bank Transfer' : 'QR Payment', b.total_amount, `/api/bookings/${req.params.code}/slip`]
        );
        await conn.commit();
      } catch (e) {
        await conn.rollback().catch(() => {});
        throw e;
      } finally {
        conn.release();
      }
      await notify(b.user_id, 'ส่งสลิปแล้ว', `รายการ ${req.params.code} ส่งสลิปเรียบร้อย รอเจ้าหน้าที่ตรวจสอบและยืนยัน`);
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  // ดูสลิป: เจ้าของรายการหรือแอดมินเท่านั้น
  app.get('/api/bookings/:code/slip', authenticate, async (req, res) => {
    try {
      const b = await ownedBooking(req.params.code, req.user);
      if (!b.slip_file) return res.status(404).json({ success: false, message: 'ยังไม่มีสลิป' });
      res.sendFile(path.join(SLIP_DIR, path.basename(b.slip_file)), { headers: { 'Cache-Control': 'private, max-age=300' } });
    } catch (error) {
      fail(res, error);
    }
  });

  // ===== เฉพาะแอดมิน =====
  // อัปโหลดรูป (โรงแรม/ห้อง): ส่ง { data: <base64> } คืน { url: '/uploads/xxx.jpg' }
  app.post('/api/admin/upload', authenticate, requireAdmin, async (req, res) => {
    try {
      const file = await saveImage(UPLOAD_DIR, req.body?.data);
      res.status(201).json({ success: true, url: `/uploads/${file}` });
    } catch (error) {
      fail(res, error);
    }
  });

  // แก้ไขข้อมูลโรงแรม — ส่งเฉพาะฟิลด์ที่ต้องการแก้
  app.put('/api/admin/hotels/:id', authenticate, requireAdmin, async (req, res) => {
    const text = (v) => (v == null ? null : String(v));
    const flag = (v) => (v ? 1 : 0);
    const map = {
      name: ['name', text],
      location: ['location', text],
      description: ['description', text],
      imageUrl: ['image_url', text],
      cancellationPolicy: ['cancellation_policy', text],
      freeCancelDays: ['free_cancel_days', (v) => Math.max(0, Number.parseInt(v, 10) || 0)],
      hasPool: ['has_pool', flag],
      hasBreakfast: ['has_breakfast', flag],
      hasWifi: ['has_wifi', flag],
      checkInTime: ['check_in_time', text],
      checkOutTime: ['check_out_time', text],
    };
    const sets = [];
    const vals = [];
    for (const [key, [col, conv]] of Object.entries(map)) {
      if (req.body?.[key] !== undefined) {
        sets.push(`${col} = ?`);
        vals.push(conv(req.body[key]));
      }
    }
    if (sets.length === 0) return res.status(400).json({ success: false, message: 'ไม่มีข้อมูลให้แก้ไข' });
    if (req.body?.name !== undefined && !String(req.body.name).trim()) {
      return res.status(400).json({ success: false, message: 'ชื่อโรงแรมต้องไม่ว่าง' });
    }
    try {
      const [r] = await db.query(`UPDATE hotels SET ${sets.join(', ')} WHERE hotel_id = ?`, [...vals, req.params.id]);
      if (r.affectedRows === 0) return res.status(404).json({ success: false, message: 'ไม่พบโรงแรมนี้' });
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  // ลบโรงแรม: ลบไม่ได้ถ้ามีรายการจองอ้างอิงอยู่ (เก็บประวัติการจองไว้)
  app.delete('/api/admin/hotels/:id', authenticate, requireAdmin, async (req, res) => {
    const conn = await db.getConnection();
    try {
      const [[{ n }]] = await conn.query('SELECT COUNT(*) AS n FROM bookings WHERE hotel_id = ?', [req.params.id]);
      if (n > 0) {
        return res.status(409).json({ success: false, message: `ลบไม่ได้ เพราะมีรายการจอง ${n} รายการ (ลบห้องที่ไม่ใช้แทนได้)` });
      }
      await conn.beginTransaction();
      await conn.query('DELETE FROM rooms WHERE hotel_id = ?', [req.params.id]);
      await conn.query('DELETE FROM hotel_tags WHERE hotel_id = ?', [req.params.id]);
      await conn.query('DELETE FROM hotel_images WHERE hotel_id = ?', [req.params.id]);
      await conn.query('DELETE FROM saved_hotels WHERE hotel_id = ?', [req.params.id]);
      await conn.query('DELETE FROM reviews WHERE hotel_id = ?', [req.params.id]);
      const [r] = await conn.query('DELETE FROM hotels WHERE hotel_id = ?', [req.params.id]);
      if (r.affectedRows === 0) {
        await conn.rollback();
        return res.status(404).json({ success: false, message: 'ไม่พบโรงแรมนี้' });
      }
      await conn.commit();
      res.json({ success: true });
    } catch (error) {
      await conn.rollback().catch(() => {});
      fail(res, error);
    } finally {
      conn.release();
    }
  });

  // แท็กโรงแรม: ส่ง { tags: ['ติดทะเล', 'รีสอร์ท'] } แทนที่ทั้งชุด
  app.put('/api/admin/hotels/:id/tags', authenticate, requireAdmin, async (req, res) => {
    const tags = [...new Set((Array.isArray(req.body?.tags) ? req.body.tags : []).map((t) => String(t).trim()).filter(Boolean))].slice(0, 20);
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      await conn.query('DELETE FROM hotel_tags WHERE hotel_id = ?', [req.params.id]);
      for (const t of tags) {
        await conn.query('INSERT INTO hotel_tags (hotel_id, tag_name) VALUES (?, ?)', [req.params.id, t.slice(0, 50)]);
      }
      await conn.commit();
      res.json({ success: true });
    } catch (error) {
      await conn.rollback().catch(() => {});
      fail(res, error);
    } finally {
      conn.release();
    }
  });

  // รูปเพิ่มเติมของโรงแรม (แกลเลอรี)
  app.post('/api/admin/hotels/:id/images', authenticate, requireAdmin, async (req, res) => {
    const url = String(req.body?.imageUrl || '');
    if (!url.startsWith('/uploads/')) return res.status(400).json({ success: false, message: 'ต้องอัปโหลดรูปก่อน' });
    try {
      const [r] = await db.query('INSERT INTO hotel_images (hotel_id, image_url) VALUES (?, ?)', [req.params.id, url]);
      res.status(201).json({ success: true, id: r.insertId });
    } catch (error) {
      fail(res, error);
    }
  });

  app.delete('/api/admin/hotel-images/:imageId', authenticate, requireAdmin, async (req, res) => {
    try {
      await db.query('DELETE FROM hotel_images WHERE id = ?', [req.params.imageId]);
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  app.get('/api/admin/hotels/:id/images', authenticate, requireAdmin, async (req, res) => {
    try {
      const [rows] = await db.query('SELECT id, image_url FROM hotel_images WHERE hotel_id = ? ORDER BY id', [req.params.id]);
      res.json({ success: true, data: rows });
    } catch (error) {
      fail(res, error);
    }
  });

  // สรุปตัวเลขสำหรับแดชบอร์ดแอดมิน
  app.get('/api/admin/stats', authenticate, requireAdmin, async (req, res) => {
    try {
      const [[b]] = await db.query(`
        SELECT COUNT(*) AS total,
               COALESCE(SUM(status = 'pending'), 0) AS pending,
               COALESCE(SUM(status = 'pending' AND slip_file IS NOT NULL), 0) AS slips_to_check,
               COALESCE(SUM(status = 'confirmed'), 0) AS confirmed,
               COALESCE(SUM(status = 'cancelled'), 0) AS cancelled,
               COALESCE(SUM(CASE WHEN status = 'confirmed' THEN total_amount END), 0) AS revenue,
               COALESCE(SUM(status IN ('pending','confirmed') AND check_in_date = CURDATE()), 0) AS checkins_today
        FROM bookings`);
      const [[h]] = await db.query('SELECT COUNT(*) AS n FROM hotels');
      const [[r]] = await db.query('SELECT COUNT(*) AS n FROM rooms');
      const [[u]] = await db.query("SELECT COUNT(*) AS n FROM users");
      res.json({
        success: true,
        bookings: Object.fromEntries(Object.entries(b).map(([k, v]) => [k, Number(v)])),
        hotels: Number(h.n),
        rooms: Number(r.n),
        users: Number(u.n),
      });
    } catch (error) {
      fail(res, error);
    }
  });

  // แอดมินกดยืนยันการจอง: pending -> confirmed แล้วแจ้งลูกค้า
  // การยืนยัน = ตัดห้องจริง: ตรวจใน transaction (ล็อกแถวห้อง) ว่าคืนไหนในช่วงเข้าพักห้องยังพอ
  // ถ้าห้องเต็มแล้ว (มีคนอื่นถูกยืนยันไปก่อน) จะยืนยันไม่ได้ ให้ปฏิเสธการจองและแจ้งลูกค้า
  app.put('/api/admin/bookings/:code/confirm', authenticate, requireAdmin, async (req, res) => {
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [rows] = await conn.query(
        "SELECT booking_id, user_id, room_id, check_in_date, check_out_date, num_rooms FROM bookings WHERE booking_code = ? AND status = 'pending' FOR UPDATE",
        [req.params.code]
      );
      if (rows.length === 0) {
        await conn.rollback();
        return res.status(409).json({ success: false, message: 'ไม่พบรายการ หรือรายการนี้ไม่ได้อยู่ในสถานะรอยืนยัน' });
      }
      const b = rows[0];
      const [room] = await conn.query('SELECT quantity FROM rooms WHERE room_id = ? FOR UPDATE', [b.room_id]);
      if (room.length > 0 && room[0].quantity != null) {
        const qty = Number(room[0].quantity) || 0;
        const peaks = await peakBookedByRoom(conn, String(b.check_in_date).slice(0, 10), String(b.check_out_date).slice(0, 10), [b.room_id]);
        const used = peaks.get(b.room_id) || 0;
        const need = Number(b.num_rooms) || 1;
        if (used + need > qty) {
          await conn.rollback();
          return res.status(409).json({
            success: false,
            message: `ห้องเต็มแล้วในช่วงวันที่นี้ (ยืนยันไว้แล้ว ${used} จาก ${qty} ห้อง ต้องการอีก ${need} ห้อง) ยืนยันไม่ได้ กรุณาปฏิเสธการจองและแจ้งลูกค้า`,
          });
        }
      }
      await conn.query("UPDATE bookings SET status = 'confirmed' WHERE booking_id = ?", [b.booking_id]);
      await conn.query("UPDATE payments SET status = 'paid' WHERE booking_id = ?", [b.booking_id]);
      await conn.commit();
      await notify(b.user_id, 'ยืนยันการจองแล้ว', `การจอง ${req.params.code} ได้รับการยืนยันแล้ว ขอให้เดินทางปลอดภัย`);
      res.json({ success: true });
    } catch (error) {
      await conn.rollback().catch(() => {});
      fail(res, error);
    } finally {
      conn.release();
    }
  });

  // แอดมินปฏิเสธ/ยกเลิกการจองแทนลูกค้า (เช่น ห้องเต็ม สลิปไม่ถูกต้อง) พร้อมเหตุผล แล้วแจ้งลูกค้า
  app.put('/api/admin/bookings/:code/cancel', authenticate, requireAdmin, async (req, res) => {
    const reason = String(req.body?.reason || '').trim().slice(0, 100) || 'ยกเลิกโดยผู้ดูแลระบบ';
    const details = String(req.body?.details || '').trim() || null;
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [rows] = await conn.query('SELECT booking_id, user_id, status FROM bookings WHERE booking_code = ? FOR UPDATE', [req.params.code]);
      if (rows.length === 0) {
        await conn.rollback();
        return res.status(404).json({ success: false, message: 'ไม่พบรายการจองนี้' });
      }
      if (rows[0].status === 'cancelled') {
        await conn.rollback();
        return res.status(400).json({ success: false, message: 'รายการจองนี้ถูกยกเลิกไปแล้ว' });
      }
      await conn.query("UPDATE bookings SET status = 'cancelled' WHERE booking_id = ?", [rows[0].booking_id]);
      await conn.query("UPDATE payments SET status = 'failed' WHERE booking_id = ? AND status = 'pending'", [rows[0].booking_id]);
      await conn.query('INSERT INTO cancellations (booking_id, reason, additional_details, cancelled_at) VALUES (?, ?, ?, NOW())', [rows[0].booking_id, reason, details]);
      await conn.commit();
      await notify(rows[0].user_id, 'การจองถูกยกเลิก', `การจอง ${req.params.code} ถูกยกเลิกโดยผู้ดูแลระบบ เหตุผล: ${reason}`);
      res.json({ success: true });
    } catch (error) {
      await conn.rollback().catch(() => {});
      fail(res, error);
    } finally {
      conn.release();
    }
  });

  // ----- จัดการดีล (แอดมิน) -----
  const dealStatus = (d) => {
    const today = todayStr();
    if (!d.is_active) return 'off';
    if (today < String(d.start_date).slice(0, 10)) return 'scheduled';
    if (today > String(d.end_date).slice(0, 10)) return 'expired';
    return 'active';
  };

  const DEAL_SELECT = `SELECT d.deal_id, d.hotel_id, h.name AS hotel_name, d.title, d.description, d.discount_percent,
                              d.start_date, d.end_date, d.is_active
                       FROM deals d LEFT JOIN hotels h ON h.hotel_id = d.hotel_id`;
  const dealRow = (d) => ({ ...d, is_active: Boolean(d.is_active), status: dealStatus(d) });

  // ตรวจและแปลงข้อมูลดีลจาก body (คืน { error } หรือ { value })
  function parseDeal(b) {
    const hotelId = Number.parseInt(b.hotelId, 10);
    const title = String(b.title ?? '').trim();
    const description = String(b.description ?? '').trim();
    const pct = Number(b.discountPercent);
    const start = String(b.startDate ?? '').slice(0, 10);
    const end = String(b.endDate ?? '').slice(0, 10);
    if (!hotelId) return { error: 'เลือกโรงแรม' };
    if (!title) return { error: 'ตั้งชื่อดีล' };
    if (title.length > 100) return { error: 'ชื่อดีลยาวเกิน 100 ตัวอักษร' };
    if (description.length > 255) return { error: 'คำอธิบายยาวเกิน 255 ตัวอักษร' };
    if (!Number.isInteger(pct) || pct < 1 || pct > 90) return { error: 'ส่วนลดต้องเป็นจำนวนเต็ม 1-90 %' };
    if (!DATE_RE.test(start) || !DATE_RE.test(end) || isNaN(new Date(start + 'T00:00:00Z')) || isNaN(new Date(end + 'T00:00:00Z'))) {
      return { error: 'ระบุวันที่เริ่มและวันที่สิ้นสุดให้ถูกต้อง (YYYY-MM-DD)' };
    }
    if (end < start) return { error: 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม' };
    return { value: { hotelId, title, description: description || null, pct, start, end, active: b.isActive === undefined ? 1 : b.isActive ? 1 : 0 } };
  }

  app.get('/api/admin/deals', authenticate, requireAdmin, async (req, res) => {
    try {
      const [rows] = await db.query(`${DEAL_SELECT} ORDER BY d.is_active DESC, d.end_date DESC, d.deal_id DESC`);
      res.json({ success: true, data: rows.map(dealRow) });
    } catch (error) {
      fail(res, error);
    }
  });

  app.post('/api/admin/deals', authenticate, requireAdmin, async (req, res) => {
    const p = parseDeal(req.body || {});
    if (p.error) return res.status(400).json({ success: false, message: p.error });
    const v = p.value;
    try {
      const [h] = await db.query('SELECT 1 FROM hotels WHERE hotel_id = ?', [v.hotelId]);
      if (h.length === 0) return res.status(404).json({ success: false, message: 'ไม่พบโรงแรมนี้' });
      const [r] = await db.query(
        'INSERT INTO deals (hotel_id, title, description, discount_percent, start_date, end_date, is_active) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [v.hotelId, v.title, v.description, v.pct, v.start, v.end, v.active]
      );
      res.status(201).json({ success: true, dealId: r.insertId });
    } catch (error) {
      fail(res, error);
    }
  });

  // แก้ดีล — ส่งเฉพาะฟิลด์ที่ต้องการแก้ (ที่ไม่ส่งใช้ค่าเดิม)
  app.put('/api/admin/deals/:id', authenticate, requireAdmin, async (req, res) => {
    try {
      const [rows] = await db.query(`${DEAL_SELECT} WHERE d.deal_id = ?`, [req.params.id]);
      if (rows.length === 0) return res.status(404).json({ success: false, message: 'ไม่พบดีลนี้' });
      const cur = rows[0];
      const b = req.body || {};
      const p = parseDeal({
        hotelId: b.hotelId ?? cur.hotel_id,
        title: b.title ?? cur.title,
        description: b.description ?? cur.description,
        discountPercent: b.discountPercent ?? cur.discount_percent,
        startDate: b.startDate ?? cur.start_date,
        endDate: b.endDate ?? cur.end_date,
        isActive: b.isActive ?? Boolean(cur.is_active),
      });
      if (p.error) return res.status(400).json({ success: false, message: p.error });
      const v = p.value;
      const [h] = await db.query('SELECT 1 FROM hotels WHERE hotel_id = ?', [v.hotelId]);
      if (h.length === 0) return res.status(404).json({ success: false, message: 'ไม่พบโรงแรมนี้' });
      await db.query(
        'UPDATE deals SET hotel_id = ?, title = ?, description = ?, discount_percent = ?, start_date = ?, end_date = ?, is_active = ? WHERE deal_id = ?',
        [v.hotelId, v.title, v.description, v.pct, v.start, v.end, v.active, req.params.id]
      );
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  // ลบดีล: การจองที่เคยใช้ดีลนี้ยังคงเก็บส่วนลดที่ได้ไว้ (deal_id ในการจองจะไม่ชี้ไปหาอะไรแล้ว)
  app.delete('/api/admin/deals/:id', authenticate, requireAdmin, async (req, res) => {
    try {
      const [r] = await db.query('DELETE FROM deals WHERE deal_id = ?', [req.params.id]);
      if (r.affectedRows === 0) return res.status(404).json({ success: false, message: 'ไม่พบดีลนี้' });
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });

  // ----- จัดการห้องพัก (แอดมิน) -----
  // หาชื่อคอลัมน์ "ชื่อห้อง" ในตาราง rooms อัตโนมัติ (ตามที่ใช้ใน GET /api/bookings)
  async function roomNameColumn() {
    const [cols] = await db.query('SHOW COLUMNS FROM rooms');
    const names = cols.map((c) => c.Field);
    return ['room_type', 'type_name', 'room_name', 'name'].find((n) => names.includes(n)) || null;
  }

  app.get('/api/admin/rooms', authenticate, requireAdmin, async (req, res) => {
    try {
      const nameCol = await roomNameColumn();
      const params = [];
      let sql = 'SELECT r.*, h.name AS hotel_name FROM rooms r LEFT JOIN hotels h ON h.hotel_id = r.hotel_id';
      if (req.query.hotelId) {
        sql += ' WHERE r.hotel_id = ?';
        params.push(req.query.hotelId);
      }
      sql += ' ORDER BY r.hotel_id, r.room_id';
      const [rows] = await db.query(sql, params);
      // คืนที่ดู (?date=YYYY-MM-DD ไม่ส่งมา = คืนนี้): ห้องว่าง = จำนวนห้องที่มี - ห้องที่แอดมิน "ยืนยันแล้ว" ในคืนนั้น
      // pending_tonight = ห้องที่ลูกค้าจองแล้วแต่ยังรอยืนยัน (ยังไม่ลดห้องว่าง)
      const night = DATE_RE.test(String(req.query.date || '')) ? String(req.query.date) : todayStr();
      const ids = rows.map((r) => r.room_id);
      const tonight = await peakBookedByRoom(db, night, addDays(night, 1), ids);
      const waiting = await peakBookedByRoom(db, night, addDays(night, 1), ids, ['pending']);
      res.json({
        success: true,
        data: rows.map((r) => {
          const booked = tonight.get(r.room_id) || 0;
          return {
            room_id: r.room_id,
            hotel_id: r.hotel_id,
            hotel_name: r.hotel_name,
            name: nameCol ? r[nameCol] : null,
            price_per_night: r.price_per_night,
            image_url: r.image_url || null,
            quantity: r.quantity,
            booked_tonight: booked,
            pending_tonight: waiting.get(r.room_id) || 0,
            night,
            rooms_available: Math.max(0, (Number(r.quantity) || 0) - booked),
            max_guests: r.max_guests,
            bed_type: r.bed_type,
            size_sqm: r.size_sqm,
          };
        }),
      });
    } catch (error) {
      fail(res, error);
    }
  });

  // แปลงฟิลด์จาก body เป็นคอลัมน์ของตาราง rooms (เฉพาะที่ส่งมา)
  function roomFields(body) {
    const intOrNull = (v) => (v === '' || v == null ? null : Math.max(0, Number.parseInt(v, 10) || 0));
    const out = {};
    if (body.quantity !== undefined) out.quantity = Math.max(1, Number.parseInt(body.quantity, 10) || 1);
    if (body.maxGuests !== undefined) out.max_guests = intOrNull(body.maxGuests);
    if (body.bedType !== undefined) out.bed_type = String(body.bedType || '').trim() || null;
    if (body.sizeSqm !== undefined) out.size_sqm = intOrNull(body.sizeSqm);
    if (body.imageUrl !== undefined) out.image_url = body.imageUrl || null;
    return out;
  }

  app.post('/api/admin/rooms', authenticate, requireAdmin, async (req, res) => {
    const { hotelId, name, price } = req.body || {};
    if (!hotelId || !name || price == null || !(Number(price) >= 0)) {
      return res.status(400).json({ success: false, message: 'ต้องระบุโรงแรม ชื่อห้อง และราคา' });
    }
    try {
      const nameCol = await roomNameColumn();
      const fields = { hotel_id: hotelId, price_per_night: price, ...roomFields(req.body) };
      if (nameCol) fields[nameCol] = String(name).trim();
      const cols = Object.keys(fields);
      const [r] = await db.query(
        `INSERT INTO rooms (${cols.join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`,
        cols.map((k) => fields[k])
      );
      res.status(201).json({ success: true, roomId: r.insertId });
    } catch (error) {
      fail(res, error);
    }
  });

  // เพิ่ม/ลดจำนวนห้องที่มี: ส่ง { delta: 1 } หรือ { delta: -1 } (หรือ { quantity: n })
  // ลดได้ไม่ต่ำกว่า 0 และไม่ต่ำกว่าจำนวนห้องที่ถูกจองไว้พร้อมกันสูงสุดตั้งแต่วันนี้เป็นต้นไป (กันห้องเกินจำนวน)
  app.put('/api/admin/rooms/:id/quantity', authenticate, requireAdmin, async (req, res) => {
    const hasQty = req.body?.quantity !== undefined;
    const delta = Number.parseInt(req.body?.delta, 10);
    const qtyIn = Number.parseInt(req.body?.quantity, 10);
    if (hasQty ? !Number.isInteger(qtyIn) : !Number.isInteger(delta)) {
      return res.status(400).json({ success: false, message: 'ระบุ delta หรือ quantity เป็นจำนวนเต็ม' });
    }
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [rows] = await conn.query('SELECT quantity FROM rooms WHERE room_id = ? FOR UPDATE', [req.params.id]);
      if (rows.length === 0) {
        await conn.rollback();
        return res.status(404).json({ success: false, message: 'ไม่พบห้องนี้' });
      }
      const current = Number(rows[0].quantity) || 0;
      const next = Math.min(9999, Math.max(0, hasQty ? qtyIn : current + delta));
      const peaks = await peakBookedByRoom(conn, todayStr(), '9999-12-31', [Number(req.params.id)]);
      const peak = peaks.get(Number(req.params.id)) || 0;
      if (next < peak) {
        await conn.rollback();
        return res.status(409).json({
          success: false,
          message: `ลดไม่ได้ เพราะมีการจองที่ยืนยันแล้วพร้อมกันสูงสุด ${peak} ห้อง (ต้องมีห้องอย่างน้อย ${peak})`,
        });
      }
      await conn.query('UPDATE rooms SET quantity = ? WHERE room_id = ?', [next, req.params.id]);
      await conn.commit();
      const today = todayStr();
      const tonight = (await peakBookedByRoom(db, today, addDays(today, 1), [Number(req.params.id)])).get(Number(req.params.id)) || 0;
      res.json({ success: true, quantity: next, booked_tonight: tonight, rooms_available: Math.max(0, next - tonight) });
    } catch (error) {
      await conn.rollback().catch(() => {});
      fail(res, error);
    } finally {
      conn.release();
    }
  });

  app.put('/api/admin/rooms/:id', authenticate, requireAdmin, async (req, res) => {
    const { name, price } = req.body || {};
    try {
      const nameCol = await roomNameColumn();
      const fields = roomFields(req.body || {});
      if (price != null) fields.price_per_night = price;
      if (name != null && nameCol) fields[nameCol] = String(name).trim();
      const cols = Object.keys(fields);
      if (cols.length === 0) return res.status(400).json({ success: false, message: 'ไม่มีข้อมูลให้แก้ไข' });
      const [r] = await db.query(`UPDATE rooms SET ${cols.map((k) => `${k} = ?`).join(', ')} WHERE room_id = ?`, [
        ...cols.map((k) => fields[k]),
        req.params.id,
      ]);
      if (r.affectedRows === 0) return res.status(404).json({ success: false, message: 'ไม่พบห้องนี้' });
      res.json({ success: true });
    } catch (error) {
      fail(res, error);
    }
  });
};
