// ไฟล์ chat.js — แชทระหว่างลูกค้ากับแอดมิน (1 ลูกค้า = 1 ห้องสนทนา)
// เรียกใช้จาก server.js: require('./chat')(app, { ...ตัวช่วยจาก server.js })
// ฝั่งแอปดึงข้อความใหม่ด้วยการ poll (?after=<id ล่าสุด>) ทุกไม่กี่วินาที
const db = require('./db');
const { notify } = require('./helpers');

const MAX_BODY = 1000;
const PAGE = 200; // ข้อความต่อการดึงหนึ่งครั้ง

async function migrate() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS support_messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        sender_role ENUM('user','admin') NOT NULL,
        sender_id INT NOT NULL,
        body VARCHAR(${MAX_BODY}) NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        read_at DATETIME NULL,
        INDEX idx_chat_thread (user_id, id),
        INDEX idx_chat_unread (user_id, sender_role, read_at)
      ) DEFAULT CHARSET=utf8mb4
    `);
  } catch (e) {
    console.error('สร้างตาราง support_messages ไม่สำเร็จ:', e.message);
  }
}

module.exports = function registerChat(app, { authenticate, requireAdmin, errText, userCols }) {
  migrate();

  const fail = (res, error) => res.status(500).json({ success: false, message: errText(error) });
  const bad = (res, message, status = 400) => res.status(status).json({ success: false, message });

  // จำกัดการส่งข้อความ: ไม่เกิน 20 ข้อความต่อนาทีต่อผู้ใช้ (กันสแปม)
  const sent = new Map();
  function tooFast(userId) {
    const now = Date.now();
    const list = (sent.get(userId) || []).filter((t) => now - t < 60000);
    list.push(now);
    sent.set(userId, list);
    return list.length > 20;
  }

  const cleanBody = (v) => String(v ?? '').trim().slice(0, MAX_BODY);

  const shape = (m, mine) => ({
    id: m.id,
    sender: m.sender_role,
    mine: m.sender_role === mine,
    body: m.body,
    created_at: m.created_at,
  });

  // ดึงข้อความของห้อง userId ที่ id > after พร้อมบอกว่า "ข้อความของฝั่งเราที่อีกฝั่งอ่านถึง id ไหนแล้ว"
  // และทำเครื่องหมายว่าอ่านแล้วสำหรับข้อความของอีกฝั่ง (peer = ฝั่งตรงข้ามของ viewer)
  async function readThread(userId, viewer, after) {
    const peer = viewer === 'user' ? 'admin' : 'user';
    const [rows] = await db.query('SELECT id, sender_role, body, created_at FROM support_messages WHERE user_id = ? AND id > ? ORDER BY id LIMIT ?', [
      userId,
      after,
      PAGE,
    ]);
    await db.query('UPDATE support_messages SET read_at = NOW() WHERE user_id = ? AND sender_role = ? AND read_at IS NULL', [userId, peer]);
    const [[r]] = await db.query('SELECT MAX(id) AS id FROM support_messages WHERE user_id = ? AND sender_role = ? AND read_at IS NOT NULL', [userId, viewer]);
    return { messages: rows.map((m) => shape(m, viewer)), readUpTo: r.id || 0 };
  }

  const afterOf = (req) => Math.max(0, parseInt(req.query.after, 10) || 0);

  // ===== ลูกค้า =====
  const customerOnly = (req, res, next) =>
    req.user.role === 'admin' ? bad(res, 'ผู้ดูแลระบบใช้แท็บ "แชท" ในหน้าแอดมิน', 403) : next();

  app.get('/api/chat', authenticate, customerOnly, async (req, res) => {
    try {
      const { messages, readUpTo } = await readThread(req.user.id, 'user', afterOf(req));
      res.json({ success: true, data: messages, read_up_to: readUpTo });
    } catch (error) {
      fail(res, error);
    }
  });

  app.post('/api/chat', authenticate, customerOnly, async (req, res) => {
    const body = cleanBody(req.body?.body);
    if (!body) return bad(res, 'พิมพ์ข้อความก่อนส่ง');
    if (tooFast(req.user.id)) return bad(res, 'ส่งข้อความถี่เกินไป กรุณารอสักครู่', 429);
    try {
      const [r] = await db.query("INSERT INTO support_messages (user_id, sender_role, sender_id, body) VALUES (?, 'user', ?, ?)", [req.user.id, req.user.id, body]);
      res.status(201).json({ success: true, id: r.insertId });
    } catch (error) {
      fail(res, error);
    }
  });

  // จำนวนข้อความจากทีมงานที่ยังไม่ได้อ่าน (ไว้แสดงป้ายแจ้งเตือน)
  app.get('/api/chat/unread', authenticate, customerOnly, async (req, res) => {
    try {
      const [[r]] = await db.query("SELECT COUNT(*) AS n FROM support_messages WHERE user_id = ? AND sender_role = 'admin' AND read_at IS NULL", [req.user.id]);
      res.json({ success: true, unread: Number(r.n) });
    } catch (error) {
      fail(res, error);
    }
  });

  // ===== แอดมิน =====
  // กล่องข้อความ: ลูกค้าที่เคยคุยแล้ว เรียงตามข้อความล่าสุด พร้อมจำนวนที่ยังไม่ได้อ่าน
  app.get('/api/admin/chats', authenticate, requireAdmin, async (req, res) => {
    try {
      const c = await userCols();
      const [rows] = await db.query(
        `SELECT t.user_id, m.body AS last_body, m.sender_role AS last_sender, m.created_at AS last_at,
                (SELECT COUNT(*) FROM support_messages x WHERE x.user_id = t.user_id AND x.sender_role = 'user' AND x.read_at IS NULL) AS unread,
                ${c.name ? 'u.' + c.name : 'NULL'} AS name, u.${c.email} AS email
         FROM (SELECT user_id, MAX(id) AS last_id FROM support_messages GROUP BY user_id) t
         JOIN support_messages m ON m.id = t.last_id
         LEFT JOIN users u ON u.${c.id} = t.user_id
         ORDER BY t.last_id DESC
         LIMIT 200`
      );
      res.json({ success: true, data: rows.map((r) => ({ ...r, unread: Number(r.unread) })) });
    } catch (error) {
      fail(res, error);
    }
  });

  app.get('/api/admin/chats/unread', authenticate, requireAdmin, async (req, res) => {
    try {
      const [[r]] = await db.query("SELECT COUNT(*) AS n, COUNT(DISTINCT user_id) AS chats FROM support_messages WHERE sender_role = 'user' AND read_at IS NULL");
      res.json({ success: true, unread: Number(r.n), chats: Number(r.chats) });
    } catch (error) {
      fail(res, error);
    }
  });

  app.get('/api/admin/chats/:userId', authenticate, requireAdmin, async (req, res) => {
    const userId = parseInt(req.params.userId, 10);
    if (!userId) return bad(res, 'ไม่พบผู้ใช้');
    try {
      const { messages, readUpTo } = await readThread(userId, 'admin', afterOf(req));
      res.json({ success: true, data: messages, read_up_to: readUpTo });
    } catch (error) {
      fail(res, error);
    }
  });

  app.post('/api/admin/chats/:userId', authenticate, requireAdmin, async (req, res) => {
    const userId = parseInt(req.params.userId, 10);
    const body = cleanBody(req.body?.body);
    if (!userId) return bad(res, 'ไม่พบผู้ใช้');
    if (!body) return bad(res, 'พิมพ์ข้อความก่อนส่ง');
    if (tooFast(req.user.id)) return bad(res, 'ส่งข้อความถี่เกินไป กรุณารอสักครู่', 429);
    try {
      const c = await userCols();
      const [u] = await db.query(`SELECT ${c.role} AS role FROM users WHERE ${c.id} = ? LIMIT 1`, [userId]);
      if (u.length === 0 || u[0].role === 'admin') return bad(res, 'ไม่พบลูกค้ารายนี้', 404);
      // แจ้งเตือนลูกค้าเฉพาะข้อความแรกที่ยังไม่ได้อ่าน (กันแจ้งเตือนรัว)
      const [[pending]] = await db.query("SELECT COUNT(*) AS n FROM support_messages WHERE user_id = ? AND sender_role = 'admin' AND read_at IS NULL", [userId]);
      const [r] = await db.query("INSERT INTO support_messages (user_id, sender_role, sender_id, body) VALUES (?, 'admin', ?, ?)", [userId, req.user.id, body]);
      if (Number(pending.n) === 0) await notify(userId, 'ข้อความใหม่จากทีมงาน', body.length > 80 ? body.slice(0, 80) + '…' : body);
      res.status(201).json({ success: true, id: r.insertId });
    } catch (error) {
      fail(res, error);
    }
  });
};
