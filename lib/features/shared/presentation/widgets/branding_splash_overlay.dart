import 'package:flutter/material.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/features/shared/presentation/widgets/shopease_brand_logo.dart';

class BrandingSplashOverlay extends StatelessWidget {
  const BrandingSplashOverlay({
    super.key,
    this.logoPath,
    this.shopName = 'ShopEase',
  });

  final String? logoPath;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    const cloudoraBlue = Color(0xFF1E88E5);
    const techGrey = Color(0xFF7A7A7A);

    return ColoredBox(
      color: pkSurface,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShopEaseBrandLogo(logoPath: logoPath, size: 96),
                  const SizedBox(height: 18),
                  Text(
                    shopName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: pkGreen,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Point of Sale',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: pkMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                      children: [
                        TextSpan(text: 'by '),
                        TextSpan(text: 'Cloudora', style: TextStyle(color: cloudoraBlue)),
                        TextSpan(text: ' '),
                        TextSpan(text: 'Tech', style: TextStyle(color: techGrey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Software Solutions',
                    style: TextStyle(fontSize: 11, color: techGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


