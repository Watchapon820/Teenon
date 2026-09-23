const express = require('express');
const cors = require('cors');
require('dotenv').config();
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// 1. GET: ดึงรายชื่อโรงแรมทั้งหมด
app.get('/api/hotels', async (req, res) => {
  try {
    const [hotels] = await db.query('SELECT * FROM hotels');
    res.json({ success: true, data: hotels });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 2. GET: ดึงข้อมูลรายละเอียดโรงแรม พร้อมประเภทห้องพัก
app.get('/api/hotels/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const [hotel] = await db.query('SELECT * FROM hotels WHERE hotel_id = ?', [id]);
    
    if (hotel.length === 0) {
      return res.status(404).json({ success: false, message: 'Hotel not found' });
    }

    const [rooms] = await db.query('SELECT * FROM rooms WHERE hotel_id = ?', [id]);
    const [tags] = await db.query('SELECT tag_name FROM hotel_tags WHERE hotel_id = ?', [id]);

    res.json({
      success: true,
      data: {
        ...hotel[0],
        tags: tags.map((t) => t.tag_name),
        rooms: rooms,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// 3. POST: บันทึกข้อมูลการจองใหม่ (Booking)
app.post('/api/bookings', async (req, res) => {
  const {
    userId,
    hotelId,
    roomId,
    guestName,
    guestEmail,
    guestPhone,
    checkIn,
    checkOut,
    numRooms,
    numGuests,
    specialRequest,
    totalAmount,
  } = req.body;

  // สุ่มสร้าง Booking Code เช่น TN-8291
  const bookingCode = 'TN-' + Math.floor(1000 + Math.random() * 9000);

  try {
    const sql = `
      INSERT INTO bookings 
      (booking_code, user_id, hotel_id, room_id, guest_name, guest_email, guest_phone, check_in_date, check_out_date, num_rooms, num_guests, special_request, total_amount)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    const [result] = await db.query(sql, [
      bookingCode,
      userId,
      hotelId,
      roomId,
      guestName,
      guestEmail,
      guestPhone,
      checkIn,
      checkOut,
      numRooms,
      numGuests,
      specialRequest,
      totalAmount,
    ]);

    res.status(201).json({
      success: true,
      message: 'Booking created successfully',
      bookingId: result.insertId,
      bookingCode: bookingCode,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/', (req, res) => {
  res.send('🚀 Backend API พร้อมใช้งานแล้ว!');
});

app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${5000}`);
});