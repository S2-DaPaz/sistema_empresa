import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AvatarInitials extends StatelessWidget {
  const AvatarInitials({
    super.key,
    required this.name,
    this.size = 42,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '--';
    }
    if (parts.length == 1) {
      final end = parts.first.length < 2 ? parts.first.length : 2;
      return parts.first.substring(0, end).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.primarySoft;
    final fg = foregroundColor ?? AppColors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
