const { fakeDb } = require('./support/env');
const test = require('node:test');
const assert = require('node:assert/strict');

// โหลด db.js ตัวจริง (แทนตัวปลอม) เพื่อตรวจค่าตั้งต้นของ connection pool — createPool ไม่ต่อฐานข้อมูลจนกว่าจะมีคำสั่ง
test('db.js: ตั้งค่า pool จาก env และคืนวันที่เป็นสตริง', async () => {
  const dbPath = require.resolve('../db');
  const saved = require.cache[dbPath];
  const env = { DB_HOST: process.env.DB_HOST, DB_NAME: process.env.DB_NAME };
  process.env.DB_HOST = 'db.example.test';
  process.env.DB_NAME = 'teenon_test';
  delete require.cache[dbPath];
  try {
    const pool = require('../db');
    assert.notEqual(pool, fakeDb);
    const cfg = pool.pool.config.connectionConfig;
    assert.equal(cfg.host, 'db.example.test');
    assert.equal(cfg.database, 'teenon_test');
    assert.equal(cfg.dateStrings, true);
    assert.equal(pool.pool.config.connectionLimit, 10);
    await pool.end();
  } finally {
    require.cache[dbPath] = saved;
    for (const [k, v] of Object.entries(env)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  }
});
