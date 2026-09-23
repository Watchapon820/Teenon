import 'package:flutter/material.dart';

import '../models/hotel.dart';
import '../theme/app_theme.dart';

class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class GradientIconBox extends StatelessWidget {
  const GradientIconBox({
    super.key,
    required this.icon,
    this.size = 48,
    this.colors = const [AppColors.primary, AppColors.teal],
  });

  final IconData icon;
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.icon, this.accent = false});

  final String label;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.teal : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class HotelCard extends StatelessWidget {
  const HotelCard({super.key, required this.hotel, required this.onTap, this.compact = false});

  final Hotel hotel;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: compact ? 104 : 132,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: hotel.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.hotel_rounded, color: Colors.white24, size: 76),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hotel.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hotel.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFEAF1FF), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 17, color: AppColors.textSoft),
                  const SizedBox(width: 4),
                  Text(hotel.location, style: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5A623)),
                  const SizedBox(width: 3),
                  Text('${hotel.rating}', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(
                    '${hotel.price.toStringAsFixed(0)}฿',
                    style: const TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const Text('/คืน', style: TextStyle(color: AppColors.textSoft, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSoft))),
          Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientIconBox(icon: icon, size: 74),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSoft)),
          ],
        ),
      ),
    );
  }
}
