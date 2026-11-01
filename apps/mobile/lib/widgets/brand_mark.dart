import 'package:flutter/material.dart';

import '../app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 40 : 46,
          height: compact ? 40 : 46,
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.translate_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AnuvaadAI',
              style: TextStyle(
                fontSize: compact ? 18 : 20,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.forest,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 3),
              const Text(
                'CLASSROOM LANGUAGE TOOLS',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
