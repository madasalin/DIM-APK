// ════════════════════════════════════════════════════════════════
//  R4 Deflector 구간 자동 검출/제거 + Runout 계산
//  데스크톱 DMD.py(2026-07-13 (4~7차) 최신 알고리즘)를 그대로 포팅했다.
//
//  ── 핵심(예전 미분/Savitzky-Golay 방식에서 전면 교체) ──
//  · 원시 샘플에 대해 median / MAD(robust scale)만 계산한다 (스무딩·미분 없음).
//  · 이력(hysteresis) 이중 임계값:
//      - deriv_k (1차/높은 임계값): |value-median| 이 이 값을 넘으면 "확실한
//        이상치"로 트리거 (방향 무관 — 위로 튀든 아래로 꺼지든 동일).
//      - recovery_k (2차/낮은 임계값): 트리거 지점 앞/뒤로 값이 이 아래로
//        떨어질 때까지만 제거 범위를 넓힌다. 2차 밑으로 내려오면 즉시
//        유효값으로 남기고 확장을 멈춘다(병합하지 않음).
//  · min_drop: median 대비 절대 편차가 이보다 작으면 노이즈로 무시.
//  · edge_margin: 각 골 구간 경계 앞/뒤로 조건 무관하게 추가 제거.
//  · zones(선택): 지정하면 그 상대구간(%) 밖에서는 이상치로 안 잡는다.
//  · Runout 등은 Method 3 — 제거 구간을 이어붙이지 않고 "유효 데이터"만으로
//    계산한다(접합부 인위적 단차 없음).
// ════════════════════════════════════════════════════════════════
import 'dart:math';

double _mean(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

double _median(List<double> xs) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2.0;
}

class MadScale {
  final double med;
  final double scale;
  MadScale(this.med, this.scale);
}

/// MAD(중앙값 절대편차) 기반 robust 스케일 — 평균/표준편차보다 이상치에
/// 덜 흔들려서, Deflector 스파이크 자체가 임계값을 같이 끌고 가버리는 것을
/// 막아준다. (DMD.py _mad_scale)
MadScale madScale(List<double> values) {
  final med = _median(values);
  final mad = _median(values.map((v) => (v - med).abs()).toList());
  final scale = mad > 1e-9 ? 1.4826 * mad : 1e-9;
  return MadScale(med, scale);
}

/// 정렬된 인덱스 집합을 (연속구간 시작, 연속구간 끝(포함)) 목록으로 묶는다.
/// (DMD.py _contiguous_ranges)
List<List<int>> _contiguousRanges(Set<int> idxSet) {
  if (idxSet.isEmpty) return [];
  final sb = idxSet.toList()..sort();
  final out = <List<int>>[];
  int s = sb[0];
  int p = sb[0];
  for (final idx in sb.sublist(1)) {
    if (idx == p + 1) {
      p = idx;
    } else {
      out.add([s, p]);
      s = p = idx;
    }
  }
  out.add([s, p]);
  return out;
}

class DeflectorRegion {
  final int start;
  final int end; // exclusive
  final int peakIdx; // median 대비 편차가 가장 큰 지점(방향 무관)
  DeflectorRegion(this.start, this.end, this.peakIdx);
}

/// 감지된 이상치 구간들 중 서로 gap 샘플 이내로 가까운 것들을 하나의
/// "디플렉터 이벤트"로 묶는다. 실제 제품 사양상 디플렉터가 총 4개인 걸
/// 알고 있으므로, 이렇게 묶어 센 개수로 검출 개수 검증에 쓴다.
/// (DMD.py group_deflector_events)
List<List<int>> groupDeflectorEvents(List<DeflectorRegion> regions, {int gap = 15}) {
  if (regions.isEmpty) return [];
  final se = regions.map((r) => [r.start, r.end - 1]).toList()
    ..sort((a, b) => a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]));
  final events = <List<int>>[
    [se[0][0], se[0][1]]
  ];
  for (final r in se.sublist(1)) {
    final s = r[0];
    final e = r[1];
    if (s - events.last[1] <= gap) {
      events.last[1] = max(events.last[1], e);
    } else {
      events.add([s, e]);
    }
  }
  return events;
}

class DetectResult {
  final List<DeflectorRegion> regions;
  final Set<int> badIdx;
  final List<double> filtered; // 원본을 그대로 반환(호출부 호환용)
  DetectResult(this.regions, this.badIdx, this.filtered);
}

/// Deflector(리드 중간에 값이 크게 튀는) 구간을 자동 검출한다. (DMD.py
/// detect_deflector_regions — 이력 이중 임계값 방식)
///
/// zones : [[loFrac, hiFrac], ...] 형태의 상대구간(0~1). null이면 전체 탐지.
DetectResult detectDeflectorRegions(
  List<double> samples, {
  double derivK = 2.5,
  double recoveryK = 1.0,
  double minDrop = 0.15,
  List<List<double>>? zones,
  double zoneMargin = 0.03,
  int edgeMargin = 0,
}) {
  final n = samples.length;
  if (n < 3) {
    return DetectResult([], <int>{}, [...samples]);
  }

  final ms = madScale(samples);
  final med = ms.med;
  final hi = derivK * ms.scale;
  final lo = recoveryK * ms.scale;

  List<List<int>>? zoneRanges;
  if (zones != null && zones.isNotEmpty) {
    zoneRanges = [];
    for (final z in zones) {
      final loI = max(0, (n * max(0.0, z[0] - zoneMargin)).toInt());
      final hiI = min(n, (n * min(1.0, z[1] + zoneMargin)).toInt());
      if (hiI > loI) zoneRanges.add([loI, hiI]);
    }
  }

  bool inAnyZone(int idx) {
    if (zoneRanges == null) return true;
    for (final z in zoneRanges) {
      if (z[0] <= idx && idx < z[1]) return true;
    }
    return false;
  }

  final dev = [for (int i = 0; i < n; i++) (samples[i] - med).abs()];

  // ① 1차(높은) 임계값을 넘는 "확실한" 이상치를 먼저 찾는다.
  final primary = <int>[
    for (int i = 0; i < n; i++)
      if (dev[i] > hi && dev[i] >= minDrop && inAnyZone(i)) i
  ];

  // ② 각 확실한 이상치의 앞/뒤로, 2차(낮은) 임계값 아래로 떨어질 때까지만
  //    확장한다 — 이미 정상 수준으로 돌아온 값은 건드리지 않는다.
  final badIdx = <int>{...primary};
  for (final i in primary) {
    int j = i + 1;
    while (j < n && dev[j] > lo) {
      badIdx.add(j);
      j++;
    }
    j = i - 1;
    while (j >= 0 && dev[j] > lo) {
      badIdx.add(j);
      j--;
    }
  }

  // ②-보강(edge_margin): 조건과 무관하게 각 골 구간 경계 앞/뒤로 추가 제거.
  if (edgeMargin > 0 && badIdx.isNotEmpty) {
    for (final r in _contiguousRanges(badIdx)) {
      final s = r[0];
      final e = r[1];
      for (int k = 1; k <= edgeMargin; k++) {
        if (s - k >= 0) badIdx.add(s - k);
        if (e + k < n) badIdx.add(e + k);
      }
    }
  }

  // ④ 표시용으로만 인접한 이상치들을 하나의 구간으로 묶는다(peak=최대 편차).
  final regions = <DeflectorRegion>[];
  final sortedBad = badIdx.toList()..sort();
  if (sortedBad.isNotEmpty) {
    int start = sortedBad[0];
    int prev = sortedBad[0];
    void flush() {
      int peakIdx = start;
      double best = dev[start];
      for (int k = start; k <= prev; k++) {
        if (dev[k] > best) {
          best = dev[k];
          peakIdx = k;
        }
      }
      regions.add(DeflectorRegion(start, prev + 1, peakIdx));
    }

    for (final idx in sortedBad.sublist(1)) {
      if (idx == prev + 1) {
        prev = idx;
      } else {
        flush();
        start = prev = idx;
      }
    }
    flush();
  }

  return DetectResult(regions, badIdx, [...samples]);
}

class RunoutStats {
  final List<double> valid;
  final double max, min, mean, runout, peak, valley, rms, roundness;
  RunoutStats({
    required this.valid,
    required this.max,
    required this.min,
    required this.mean,
    required this.runout,
    required this.peak,
    required this.valley,
    required this.rms,
    required this.roundness,
  });
}

/// Method 3: Deflector 구간을 이어붙이지 않고, 제외한 유효 데이터만으로
/// MAX/MIN/Runout/Peak/Valley/RMS/Roundness를 계산한다. (DMD.py
/// compute_runout_stats)
RunoutStats? computeRunoutStats(List<double> samples, Set<int> badIdx) {
  final valid = <double>[];
  for (int i = 0; i < samples.length; i++) {
    if (!badIdx.contains(i)) valid.add(samples[i]);
  }
  if (valid.length < 2) return null;
  final vmax = valid.reduce(max);
  final vmin = valid.reduce(min);
  final mean = _mean(valid);
  final runout = vmax - vmin;
  final rms = sqrt(valid.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / valid.length);
  return RunoutStats(
    valid: valid,
    max: vmax,
    min: vmin,
    mean: mean,
    runout: runout,
    peak: vmax - mean,
    valley: mean - vmin,
    rms: rms,
    roundness: runout / 2.0,
  );
}

/// R1~R3: 단순 최대값-최소값. (DMD.py calc_range)
double? calcRange(List<double> samples) {
  if (samples.isEmpty) return null;
  return samples.reduce(max) - samples.reduce(min);
}

class R4Result {
  final double? runout;
  final RunoutStats? stats;
  final List<int> removedIdx;
  final List<DeflectorRegion> regions;
  R4Result(this.runout, this.stats, this.removedIdx, this.regions);
}

/// R4: Deflector(이력 이중임계값 기반 이상치) 구간 자동 제거 후 Method 3로
/// Runout 계산. (DMD.py calc_r4)
R4Result calcR4(
  List<double> samples, {
  double derivK = 2.5,
  double recoveryK = 1.0,
  double minDrop = 0.15,
  int edgeMargin = 0,
  List<List<double>>? zones,
}) {
  final det = detectDeflectorRegions(
    samples,
    derivK: derivK,
    recoveryK: recoveryK,
    minDrop: minDrop,
    edgeMargin: edgeMargin,
    zones: zones,
  );
  final stats = computeRunoutStats(samples, det.badIdx);
  final removed = det.badIdx.toList()..sort();
  return R4Result(stats?.runout, stats, removed, det.regions);
}
