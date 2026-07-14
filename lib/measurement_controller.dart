// ════════════════════════════════════════════════════════════════
//  측정 컨트롤러 — 데스크톱 MainWindow의 핵심 로직(버퍼 누적, 스캔
//  시작/정지, 영점설정/초기화, R1~R4 결과 계산)을 그대로 포팅했다.
//  실장비(FTDI OTG) / 데모(통신 포맷 시뮬레이터) 두 가지 소스를 모두
//  지원하며, 위쪽 UI(HomeScreen)는 이 컨트롤러의 상태만 구독하면 된다.
// ════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'algorithms.dart';
import 'protocol.dart';
import 'settings.dart';
import 'theme.dart';
import 'usb_serial_service.dart';

enum ScanMode { idle, real, demo }

class MeasurementController extends ChangeNotifier {
  MeasurementController(this.settings, this.serial);

  AppSettings settings;
  final UsbFtdiService serial;

  final Map<String, List<double>> buffers = {for (final ch in chNames) ch: <double>[]};
  List<int> removedR4 = [];
  List<DeflectorRegion> r4Regions = [];
  RunoutStats? r4Stats;

  // ── 디플렉터 개수 검증 (DMD.py (7차)) ──
  int r4DeflectorEvents = 0; // 가까운 구간끼리 묶은 "진짜 이벤트" 개수
  bool? r4CountOk; // 기대 개수와 일치하면 true, 아니면 false, 미측정이면 null
  final Map<String, double?> lastValues = {for (final ch in chNames) ch: null};
  final Map<String, bool?> lastPass = {for (final ch in chNames) ch: null};
  final Map<String, double> zeroOffsets = {for (final ch in chNames) ch: 0.0};

  ScanMode mode = ScanMode.idle;
  String status = "대기";
  bool get isScanning => mode != ScanMode.idle;

  final _rnd = Random();
  bool _stopRequested = false;
  StreamSubscription<List<int>>? _demoTicker;

  // ── 스캔 시작/정지 ───────────────────────────────────
  Future<void> toggleScan() async {
    if (isScanning) {
      _stopRequested = true;
      return;
    }
    _resetBuffers();
    _stopRequested = false;

    if (serial.isConnected) {
      mode = ScanMode.real;
      status = "[실장비] ${serial.device?.deviceName ?? ''} 연결됨 — 스캔 중";
      notifyListeners();
      await _runRealScan();
    } else {
      mode = ScanMode.demo;
      status = "⚠ 실장비 미연결 — 데모(가상 통신 포맷)로 스캔 중 (설정에서 USB 장치를 연결하면 실장비로 전환됩니다)";
      notifyListeners();
      await _runDemoScan();
    }
  }

  Future<void> toggleDemoProtocol() async {
    if (isScanning) {
      _stopRequested = true;
      return;
    }
    _resetBuffers();
    _stopRequested = false;
    mode = ScanMode.demo;
    status = "[데모] 실제 통신 포맷(ENQ/ETX)으로 가상 프레임 생성·파싱 중";
    notifyListeners();
    await _runDemoScan();
  }

  void _resetBuffers() {
    for (final ch in chNames) {
      buffers[ch] = [];
    }
    removedR4 = [];
    r4Regions = [];
    r4Stats = null;
    r4DeflectorEvents = 0;
    r4CountOk = null;
  }

  // ── 실장비 스캔: START 명령 반복 전송 → 프레임 수신/파싱 ──
  Future<void> _runRealScan() async {
    final end = DateTime.now().add(Duration(milliseconds: (settings.scanDurationSec * 1000).round()));
    final flushInterval = const Duration(milliseconds: 50);
    var lastFlush = DateTime.now();

    while (!_stopRequested && DateTime.now().isBefore(end)) {
      await serial.writeCommand("START");
      final frame = await serial.waitFrame(timeout: const Duration(milliseconds: 1000));
      if (frame != null) {
        final parsed = parseProtocolFrame(frame);
        if (parsed != null) {
          for (int i = 0; i < chNames.length; i++) {
            if (i < parsed.values.length && parsed.values[i] != null) {
              final v = parsed.values[i]! - zeroOffsets[chNames[i]]!;
              buffers[chNames[i]]!.add(v);
            }
          }
        }
      } else {
        status = "⚠ 응답 없음 — 케이블/전원을 확인해 주세요";
      }
      if (DateTime.now().difference(lastFlush) >= flushInterval) {
        notifyListeners();
        lastFlush = DateTime.now();
      }
    }
    _finishScan();
  }

  // ── 데모 스캔: 실제 프레임 포맷으로 만들고 그대로 다시 파싱(왕복 검증) ──
  Future<void> _runDemoScan() async {
    final end = DateTime.now().add(Duration(milliseconds: (settings.scanDurationSec * 1000).round()));
    final flushInterval = const Duration(milliseconds: 20);
    var lastFlush = DateTime.now();
    bool grooveZone = false;
    int grooveLeft = 0;

    while (!_stopRequested && DateTime.now().isBefore(end)) {
      final vals = <double>[
        0.888 + (_rnd.nextDouble() * 0.04 - 0.02),
        0.500 + (_rnd.nextDouble() * 0.03 - 0.015),
        0.700 + (_rnd.nextDouble() * 0.05 - 0.025),
      ];
      if (!grooveZone && _rnd.nextDouble() < 0.003) {
        grooveZone = true;
        grooveLeft = 4 + _rnd.nextInt(7);
      }
      double r4Val;
      if (grooveZone) {
        r4Val = 0.400 + (_rnd.nextDouble() * 0.04 - 0.02) - (0.08 + _rnd.nextDouble() * 0.18);
        grooveLeft--;
        if (grooveLeft <= 0) grooveZone = false;
      } else {
        r4Val = 0.400 + (_rnd.nextDouble() * 0.04 - 0.02);
      }
      vals.add(r4Val);

      final frame = buildProtocolFrame(settings.deviceId, vals, decimal: true);
      final parsed = parseProtocolFrame(frame);
      if (parsed != null) {
        for (int i = 0; i < chNames.length; i++) {
          if (i < parsed.values.length && parsed.values[i] != null) {
            buffers[chNames[i]]!.add(parsed.values[i]!);
          }
        }
      }

      if (DateTime.now().difference(lastFlush) >= flushInterval) {
        notifyListeners();
        lastFlush = DateTime.now();
      }
      await Future.delayed(const Duration(milliseconds: 2)); // 약 500Hz 근사
    }
    _finishScan();
  }

  void _finishScan() {
    mode = ScanMode.idle;
    refreshResults();
    final countWarn = r4CountOk == false
        ? " ⚠ 디플렉터 $r4DeflectorEvents개 감지(기대 ${settings.expectedDeflectorCount}개) — 재측정 필요"
        : "";
    status = "스캔 완료 — 채널별 샘플 ${buffers['R1']?.length ?? 0}개"
        "${removedR4.isNotEmpty ? ' (R4 Deflector ${removedR4.length}개 제거)' : ''}"
        "$countWarn";
    notifyListeners();
  }

  // ── 영점설정 / 영점 초기화 ───────────────────────────
  Future<(bool, String)> doZero() async {
    if (isScanning) return (false, "스캔 중에는 영점설정을 할 수 없습니다.");
    final cmd = settings.zeroCmd;
    if (serial.isConnected) {
      await serial.writeCommand(cmd);
      final resp = await serial.waitFrame(timeout: const Duration(milliseconds: 500));
      final ok = resp != null && resp.isNotEmpty && resp.first == 0x41; // 'A'
      if (ok) {
        status = "영점설정 완료 ('$cmd' 전송, 응답 확인됨)";
        notifyListeners();
        return (true, "'$cmd' 명령을 전송했고 장비 응답을 확인했습니다.");
      }
      status = "영점설정 응답 없음 — mock 오프셋으로 대체 적용";
      _applyMockZero();
      notifyListeners();
      return (false, "'$cmd' 명령에 응답이 없었습니다. (mock 오프셋으로 대체 적용)");
    }
    _applyMockZero();
    notifyListeners();
    return (true, "'$cmd' 명령을 (데모 모드로) 반영했습니다. 다음 스캔부터 반영됩니다.");
  }

  Future<(bool, String)> doClear() async {
    if (isScanning) return (false, "스캔 중에는 초기화를 할 수 없습니다.");
    final cmd = settings.clearCmd;
    for (final ch in chNames) {
      zeroOffsets[ch] = 0.0;
    }
    if (serial.isConnected) {
      await serial.writeCommand(cmd);
      final resp = await serial.waitFrame(timeout: const Duration(milliseconds: 500));
      final ok = resp != null && resp.isNotEmpty && resp.first == 0x41;
      status = ok ? "영점 초기화 완료 ('$cmd' 전송, 응답 확인됨)" : "영점 초기화 응답 없음 (오프셋은 초기화됨)";
      notifyListeners();
      return (ok, ok ? "'$cmd' 명령을 전송했고 장비 응답을 확인했습니다." : "'$cmd' 명령에 응답이 없었습니다.");
    }
    status = "영점 초기화 완료 (데모 모드)";
    notifyListeners();
    return (true, "'$cmd' 명령을 (데모 모드로) 반영했습니다.");
  }

  void _applyMockZero() {
    for (final ch in chNames) {
      final buf = buffers[ch] ?? [];
      zeroOffsets[ch] = buf.isEmpty ? 0.0 : buf.reduce((a, b) => a + b) / buf.length;
    }
  }

  // ── 결과 계산 (R1~R3: range, R4: Deflector 제외 Runout) ──
  void refreshResults() {
    for (final ch in ["R1", "R2", "R3"]) {
      final buf = buffers[ch] ?? [];
      final r = calcRange(buf);
      _applyResult(ch, r);
    }
    final buf4 = buffers["R4"] ?? [];
    final res = calcR4(
      buf4,
      derivK: settings.derivK,
      recoveryK: settings.recoveryK,
      minDrop: settings.minDrop,
      edgeMargin: settings.edgeMargin,
      zones: settings.useZoneHints ? settings.zoneHints : null,
    );
    removedR4 = res.removedIdx;
    r4Regions = res.regions;
    r4Stats = res.stats;

    // 디플렉터 개수 검증: 가까운 구간끼리 묶어 "진짜 이벤트" 개수를 세고,
    // 기대 개수(기본 4개)와 다르면 재측정 필요로 표시한다.
    final events = groupDeflectorEvents(res.regions, gap: settings.eventMergeGap);
    r4DeflectorEvents = events.length;
    r4CountOk = res.regions.isEmpty ? null : (events.length == settings.expectedDeflectorCount);

    _applyResult("R4", res.runout);
  }

  void _applyResult(String ch, double? value) {
    final tol = settings.tol[ch] ?? [0.0, 100.0];
    lastValues[ch] = value;
    if (value == null) {
      lastPass[ch] = null;
      return;
    }
    lastPass[ch] = value >= tol[0] && value <= tol[1];
  }

  /// 사용자가 제시했던 예시(표) 데이터로 알고리즘만 즉시 검증하는 용도.
  void loadDemoTableData(List<double> r4Combined, List<double> r1, List<double> r2) {
    buffers["R1"] = r1;
    buffers["R2"] = r2;
    buffers["R3"] = [];
    buffers["R4"] = r4Combined;
    refreshResults();
    status = "[예시 데이터] R4 원본 ${r4Combined.length}개 처리 완료";
    notifyListeners();
  }
}
