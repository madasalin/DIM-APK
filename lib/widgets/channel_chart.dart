import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

class ChannelChart extends StatelessWidget {
  final String title;
  final List<double> data;
  final List<int> removedIdx; // R4 전용: Deflector로 제거된 인덱스
  final List<int> peakIdx; // R4 전용: 각 구간의 median 대비 최대 편차 지점

  /// 화면에 실제로 그릴 최대 점 개수. 스캔이 길어져 원본 샘플이 수천 개가
  /// 되어도 그래프 렌더링 비용은 이 값으로 상한을 둔다. (계산/판정 결과는
  /// 항상 원본 전체 버퍼로 계산되므로 값 정확도에는 영향이 없다.)
  final int maxPoints;

  const ChannelChart({
    super.key,
    required this.title,
    required this.data,
    this.removedIdx = const [],
    this.peakIdx = const [],
    this.maxPoints = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
        child: Text(title, style: const TextStyle(color: AppColors.neutral, fontSize: 12)),
      );
    }

    // 다운샘플링: 원본 인덱스 i를 표시용 x좌표 i/step 으로 선형 매핑해서,
    // 라인은 듬성듬성 그리되 제거/Valley 마커는 실제 위치 비율에 맞게 얹는다.
    final step = data.length > maxPoints ? (data.length / maxPoints).ceil() : 1;
    double xFor(int i) => i / step;

    final spots = <FlSpot>[
      for (int i = 0; i < data.length; i += step) FlSpot(xFor(i), data[i]),
    ];
    if ((data.length - 1) % step != 0) {
      spots.add(FlSpot(xFor(data.length - 1), data[data.length - 1]));
    }

    final removedSpots = <FlSpot>[
      for (final i in removedIdx)
        if (i >= 0 && i < data.length) FlSpot(xFor(i), data[i])
    ];
    final peakSpots = <FlSpot>[
      for (final v in peakIdx)
        if (v >= 0 && v < data.length) FlSpot(xFor(v), data[v])
    ];

    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.titleColor)),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: AppColors.accent,
                    barWidth: 1.4,
                    dotData: const FlDotData(show: false),
                  ),
                  if (removedSpots.isNotEmpty)
                    LineChartBarData(
                      spots: removedSpots,
                      isCurved: false,
                      color: Colors.transparent, // 선은 숨기고 점만 표시(제거된 구간 표식)
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(radius: 2.5, color: AppColors.fail, strokeWidth: 0),
                      ),
                    ),
                  if (peakSpots.isNotEmpty)
                    LineChartBarData(
                      spots: peakSpots,
                      isCurved: false,
                      color: Colors.transparent, // 선은 숨기고 점만 표시(이상 정점 표식)
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(radius: 4, color: const Color(0xFFE8A33D), strokeWidth: 0),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (removedSpots.isNotEmpty || peakSpots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                "제거 ${removedSpots.length}개 · 정점 ${peakSpots.length}개",
                style: const TextStyle(fontSize: 9, color: AppColors.fail),
              ),
            ),
        ],
      ),
    );
  }
}
