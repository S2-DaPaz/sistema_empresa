import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_assets.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 28,
    this.color,
    this.monogram = false,
  });

  final double height;
  final Color? color;
  final bool monogram;

  @override
  Widget build(BuildContext context) {
    final asset = monogram
        ? AppAssets.brandMonogram
        : (color == Colors.white
            ? AppAssets.brandWordmarkLight
            : AppAssets.brandWordmarkDark);

    return SvgPicture.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      colorFilter: monogram && color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
