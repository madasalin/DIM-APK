import 'package:flutter/material.dart';
import '../theme.dart';

class ValueCard extends StatelessWidget {
  final String name;
  final double? value;
  final bool? pass; // null=중립, true=합격, false=불합격
  final int sampleCount;
  final List<double> tol;
  final String extra;
  final bool isGroove;

  const ValueCard({
    super.key,
    required this.name,
    required this.value,
    required this.pass,
    required this.sampleCount,
    required this.tol,
    this.extra = "",
    this.isGroove = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, fg, subColor;
    if (pass == true) {
      bg = AppColors.pass;
      fg = Colors.white;
      subColor = const Color(0xFFE4F3EA);
    } else if (pass == false) {
      bg = AppColors.fail;
      fg = Colors.white;
      subColor = const Color(0xFFFBE6E3);
    } else {
      bg = Colors.white;
      fg = AppColors.titleColor;
      subColor = AppColors.neutral;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(name,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: pass == null ? const Color(0xFF22344A) : fg)),
              const Spacer(),
              if (isGroove)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                  child: const Text("Deflector 제거 적용", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: Center(
              child: Text(
                value == null ? "--" : value!.toStringAsFixed(3),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: fg),
              ),
            ),
          ),
          Text(
            "샘플 $sampleCount개 · 공차 ${tol[0]}~${tol[1]}$extra",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: subColor),
          ),
        ],
      ),
    );
  }
}
