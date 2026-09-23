import 'package:flutter/material.dart';

import '../models/hotel.dart';

const hotels = <Hotel>[
  Hotel(
    name: 'Hotel M at Zone B',
    location: 'กรุงเทพฯ',
    rating: 4.8,
    price: 1590,
    subtitle: 'City skyline • Rooftop pool • Breakfast included',
    gradient: [Color(0xFF153C7A), Color(0xFF276EF1)],
    tags: ['สระว่ายน้ำ', 'อาหารเช้า', 'Wi‑Fi'],
  ),
  Hotel(
    name: 'Siam Riverside Hotel',
    location: 'กรุงเทพฯ',
    rating: 4.6,
    price: 1890,
    subtitle: 'River view • Spacious rooms • Flexible booking',
    gradient: [Color(0xFF0F706B), Color(0xFF18B6A4)],
    tags: ['วิวแม่น้ำ', 'อาหารเช้า', 'ฟิตเนส'],
  ),
  Hotel(
    name: 'Blue Coast Resort',
    location: 'หัวหิน',
    rating: 4.9,
    price: 2650,
    subtitle: 'Sea breeze • Romantic stay • Weekend deal',
    gradient: [Color(0xFF6B3B1B), Color(0xFFF29D38)],
    tags: ['ติดทะเล', 'สระว่ายน้ำ', 'วิวพระอาทิตย์ตก'],
  ),
  Hotel(
    name: 'Lanna City Stay',
    location: 'เชียงใหม่',
    rating: 4.7,
    price: 1790,
    subtitle: 'Old town charm • Café nearby • Quiet room',
    gradient: [Color(0xFF3F3A7A), Color(0xFF7A73E8)],
    tags: ['ใกล้เมืองเก่า', 'คาเฟ่', 'ที่จอดรถ'],
  ),
];
