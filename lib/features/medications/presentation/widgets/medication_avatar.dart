import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class MedicationAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final double radius;

  const MedicationAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 56,
    this.radius = 16,
  });

  String _initials() {
    final normalized = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return 'دو';
    final words = normalized.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length >= 2) {
      final first = words[0].runes.first;
      final second = words[1].runes.first;
      return String.fromCharCodes([first, second]);
    }
    final runes = normalized.runes.toList();
    return String.fromCharCodes(runes.take(2));
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        _initials(),
        maxLines: 1,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return _fallback(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }
}
