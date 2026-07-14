import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

/// 데스크톱 AppSettings(dim_settings.json)에 대응.
class AppSettings {
  int baudRate;
  int dataBits;
  String parity; // N/E/O
  int stopBits; // 1,2 (1.5는 안드로이드 USB serial에서 잘 안 쓰여 정수로 단순화)
  String zeroCmd;
  String clearCmd;
  String deviceId;

  double scanDurationSec;

  // ── R4 Deflector 검출 파라미터 (DMD.py 최신 알고리즘 기준) ──
  double derivK; // 1차(확실한 이상치) 임계값 — median 대비 MAD 배수, 방향 무관
  double recoveryK; // 2차(확장) 임계값 — 이 아래로 떨어지면 정상 복귀로 간주 (derivK보다 작아야 함)
  double minDrop; // 절대 낙차 최소값 — 이보다 작은 튐은 노이즈로 무시
  int edgeMargin; // 골 구간 앞/뒤로 조건 무관하게 추가 제거할 샘플 수

  // ── 디플렉터 개수 검증 ──
  int expectedDeflectorCount; // 정상이면 항상 이 개수여야 함
  int eventMergeGap; // 이 간격(샘플) 이내로 가까운 구간은 같은 디플렉터로 간주

  // ── 구간 힌트(선택) ──
  bool useZoneHints; // 켜면 zoneHints 밖에서는 이상치로 안 잡는다
  List<List<double>> zoneHints; // 상대구간(0~1) 목록

  Map<String, List<double>> tol;

  AppSettings({
    this.baudRate = 9600,
    this.dataBits = 8,
    this.parity = "N",
    this.stopBits = 1,
    this.zeroCmd = "MZERO",
    this.clearCmd = "MCLEAR",
    this.deviceId = "01",
    this.scanDurationSec = 2.0,
    this.derivK = 2.5,
    this.recoveryK = 1.0,
    this.minDrop = 0.15,
    this.edgeMargin = 1,
    this.expectedDeflectorCount = 4,
    this.eventMergeGap = 15,
    this.useZoneHints = false,
    List<List<double>>? zoneHints,
    Map<String, List<double>>? tol,
  })  : zoneHints = zoneHints ?? defaultZoneHints(),
        tol = tol ?? {for (final ch in chNames) ch: [0.0, 100.0]};

  static List<List<double>> defaultZoneHints() => [
        [0.02, 0.08],
        [0.20, 0.36],
        [0.46, 0.64],
        [0.70, 0.81],
      ];

  Map<String, dynamic> toJson() => {
        "baudRate": baudRate,
        "dataBits": dataBits,
        "parity": parity,
        "stopBits": stopBits,
        "zeroCmd": zeroCmd,
        "clearCmd": clearCmd,
        "deviceId": deviceId,
        "scanDurationSec": scanDurationSec,
        "derivK": derivK,
        "recoveryK": recoveryK,
        "minDrop": minDrop,
        "edgeMargin": edgeMargin,
        "expectedDeflectorCount": expectedDeflectorCount,
        "eventMergeGap": eventMergeGap,
        "useZoneHints": useZoneHints,
        "zoneHints": zoneHints.map((z) => [z[0], z[1]]).toList(),
        "tol": tol.map((k, v) => MapEntry(k, v)),
      };

  static AppSettings fromJson(Map<String, dynamic> j) {
    final s = AppSettings();
    s.baudRate = j["baudRate"] ?? 9600;
    s.dataBits = j["dataBits"] ?? 8;
    s.parity = j["parity"] ?? "N";
    s.stopBits = j["stopBits"] ?? 1;
    s.zeroCmd = j["zeroCmd"] ?? "MZERO";
    s.clearCmd = j["clearCmd"] ?? "MCLEAR";
    s.deviceId = j["deviceId"] ?? "01";
    s.scanDurationSec = (j["scanDurationSec"] ?? 2.0).toDouble();
    s.derivK = (j["derivK"] ?? 2.5).toDouble();
    s.recoveryK = (j["recoveryK"] ?? 1.0).toDouble();
    s.minDrop = (j["minDrop"] ?? 0.15).toDouble();
    s.edgeMargin = (j["edgeMargin"] ?? 1) is int ? (j["edgeMargin"] ?? 1) : (j["edgeMargin"] as num).round();
    s.expectedDeflectorCount = (j["expectedDeflectorCount"] ?? 4) is int
        ? (j["expectedDeflectorCount"] ?? 4)
        : (j["expectedDeflectorCount"] as num).round();
    s.eventMergeGap =
        (j["eventMergeGap"] ?? 15) is int ? (j["eventMergeGap"] ?? 15) : (j["eventMergeGap"] as num).round();
    s.useZoneHints = j["useZoneHints"] ?? false;
    if (j["zoneHints"] != null) {
      s.zoneHints = (j["zoneHints"] as List)
          .map((z) => (z as List).map((e) => (e as num).toDouble()).toList())
          .toList();
    }
    if (j["tol"] != null) {
      final m = <String, List<double>>{};
      (j["tol"] as Map).forEach((k, v) {
        m[k as String] = (v as List).map((e) => (e as num).toDouble()).toList();
      });
      s.tol = m;
    }
    return s;
  }

  static const _key = "dim_settings_json";

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
