import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../theme.dart';

/// The company logo when one is set, otherwise the AK monogram: a blue
/// square with the initials set in white.
class AkMonogram extends StatelessWidget {
  const AkMonogram({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = context.watch<Repository>().companyLogo;
    if (logo != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Image.memory(logo, fit: BoxFit.contain),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AkPalette.blue,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(
        'AK',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
          letterSpacing: -0.5,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// Monogram plus the company name, for headers.
class AkWordmark extends StatelessWidget {
  const AkWordmark({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AkMonogram(size: 32),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle ?? 'AK System',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: ak.onChrome,
                height: 1.1,
              ),
            ),
            Text(
              'DESIGN · CONSULTANCY · CONTRACTING'.tr,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 8.5,
                // Spacing would break the joined letters of Arabic.
                letterSpacing: isArabic ? 0 : 1.4,
                color: ak.onChromeMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The project's position in the stage sequence, one segment per stage,
/// like a drawing register's issue strip.
class StageBar extends StatelessWidget {
  const StageBar({super.key, required this.stages, required this.currentId});

  final List<Stage> stages;
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final current = stages.indexWhere((s) => s.id == currentId);
    return Row(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Tooltip(
              message: stages[i].name.tr,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < current
                      ? ak.accent.withValues(alpha: 0.55)
                      : i == current
                      ? ak.accent
                      : ak.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
