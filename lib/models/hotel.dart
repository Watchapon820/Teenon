import 'package:flutter/material.dart';

class Hotel {
  const Hotel({
    required this.name,
    required this.location,
    required this.rating,
    required this.price,
    required this.subtitle,
    required this.gradient,
    required this.tags,
  });

  final String name;
  final String location;
  final double rating;
  final int price;
  final String subtitle;
  final List<Color> gradient;
  final List<String> tags;
}
