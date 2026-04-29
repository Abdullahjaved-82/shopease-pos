import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class ShopEaseBrandLogo extends StatelessWidget {
  const ShopEaseBrandLogo({
    super.key,
    this.logoPath,
    this.size = 92,
    this.showRing = true,
  });

  final String? logoPath;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final trimmedPath = logoPath?.trim();
    final file = (trimmedPath != null && trimmedPath.isNotEmpty) ? File(trimmedPath) : null;
    final hasLogo = file?.existsSync() ?? false;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: showRing ? Border.all(color: pkGold, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: pkGreen.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: hasLogo
            ? Image.file(file!, fit: BoxFit.cover)
            : DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [pkGreen, pkGreenLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: size * 0.42,
                      color: pkGoldSoft.withValues(alpha: 0.85),
                    ),
                    Positioned(
                      bottom: size * 0.12,
                      child: Text(
                        'SE',
                        style: TextStyle(
                          color: pkGold,
                          fontSize: size * 0.18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
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


