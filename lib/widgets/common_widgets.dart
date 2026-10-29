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

/// โลโก้แอป (เตียง + พระจันทร์) ตัวเดียวกับไอคอนแอปบนมือถือ
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 50, this.admin = false});

  final double size;

  /// true = โลโก้โทนฟ้าสำหรับฝั่งแอดมิน
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(admin ? 'assets/images/app_logo_admin.png' : 'assets/images/app_logo.png', width: size, height: size, fit: BoxFit.cover),
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
                    style: const TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w800),
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

/// ราคาบาท: จำนวนเต็มไม่มีทศนิยม ถ้ามีเศษแสดง 2 ตำแหน่ง (เช่น ราคาหลังส่วนลด 3.75)
String formatBaht(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// พื้นหลังแบนเนอร์โรงแรม: ใช้รูปโรงแรมถ้ามี (ลดความสว่างลงให้ตัวอักษรสีขาวอ่านง่าย)
/// สีไล่ [gradient] เป็นพื้นด้านหลัง จึงยังเห็นสีสวย ๆ ระหว่างรูปกำลังโหลดหรือถ้าโหลดรูปไม่ได้
BoxDecoration hotelBannerDecoration({String? imageUrl, required List<Color> gradient, double radius = 20}) {
  return BoxDecoration(
    gradient: LinearGradient(colors: gradient),
    image: imageUrl == null
        ? null
        : DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.darken),
          ),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// ปุ่มไอคอนวงกลมสีขาวขอบอ่อน ไอคอนสีส้ม ใช้ที่แถบบนของแอป
final ButtonStyle appBarIconStyle = IconButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: AppColors.primary,
  fixedSize: const Size(42, 42),
  side: const BorderSide(color: AppColors.border),
);

/// ปุ่มไอคอนวงกลมสีขาวขอบอ่อน สีไอคอนตามธีมที่ส่งมา ใช้ที่แถบบนของหน้าแอดมิน
ButtonStyle appBarIconStyleWith(Color color, Color border) => IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: color,
      fixedSize: const Size(42, 42),
      side: BorderSide(color: border),
    );

class NavItem {
  const NavItem(this.icon, this.label, {this.badge = 0});
  final IconData icon;
  final String label;
  final int badge;
}

/// แท็บบาร์ล่างแบบแคปซูล: แท็บที่เลือกเป็นเม็ดสีมีไอคอน+ชื่อ แท็บอื่นเป็นไอคอนเฉย ๆ (ใช้ทั้งฝั่งผู้ใช้และแอดมิน)
class PillNavBar extends StatelessWidget {
  const PillNavBar({super.key, required this.items, required this.currentIndex, required this.onTap, required this.color});

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final many = items.length > 5;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x1A5A4A2B), blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  flex: i == currentIndex ? (many ? 4 : 3) : 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      height: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == currentIndex ? color : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Badge(
                            isLabelVisible: items[i].badge > 0,
                            label: Text(items[i].badge > 9 ? '9+' : '${items[i].badge}'),
                            child: Icon(items[i].icon, size: many ? 22 : 23, color: i == currentIndex ? Colors.white : AppColors.textSoft),
                          ),
                          if (i == currentIndex) ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                items[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                                style: TextStyle(color: Colors.white, fontSize: many ? 12 : 13, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
