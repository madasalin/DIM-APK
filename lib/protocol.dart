// ════════════════════════════════════════════════════════════════
//  실제 장비 통신 프로토콜 (ASCII 프레임) — 파서 / 빌더
//  데스크톱 DMD.py 의 parse_protocol_frame() / build_protocol_frame() 과
//  완전히 동일한 규칙으로 포팅했다.
//
//    ENQ(0x05) + ID(2) + ',' + DataNum(2) + ',' + Data1 + ',' + Data2 + ...
//      + ETX(0x03) + '@@' + CR(0x0D) + LF(0x0A)
//
//  데이터 표기 두 형식 모두 자동 인식:
//    · 소수점 포함: "+0.888" (6 byte)
//    · 소수점 미포함(DIP 스위치): "+0888" (5 byte, 마지막 3자리=소수부)
//
//  시리얼 명령어: START(1회 측정) / MZERO(영점설정) / MCLEAR(영점초기화)
//    형식: [COMMAND]\r\n → [ACK]  (ACK = 'A'\r\n, 약 5msec 후 응답)
// ════════════════════════════════════════════════════════════════
import 'dart:typed_data';

const List<int> protocolEnq = [0x05];
const List<int> protocolEtx = [0x03];
const List<int> protocolTail = [0x40, 0x40]; // '@@'

class ProtocolFrame {
  final String id;
  final int count;
  final List<double?> values;
  ProtocolFrame({required this.id, required this.count, required this.values});
}

double? _parseProtocolValue(String token) {
  final s = token.trim();
  if (s.isEmpty) return null;
  double sign = 1.0;
  String body = s;
  if (s.startsWith('-')) {
    sign = -1.0;
    body = s.substring(1);
  } else if (s.startsWith('+')) {
    body = s.substring(1);
  }
  if (body.contains('.')) {
    final v = double.tryParse(body);
    return v == null ? null : sign * v;
  }
  final ival = int.tryParse(body);
  if (ival == null) return null;
  // 소수점 없는 정수형(DIP 스위치 설정) — 마지막 3자리를 소수부로 간주
  return sign * (ival / 1000.0);
}

/// ENQ...ETX@@CRLF 프레임(바이트)을 파싱한다. 형식이 맞지 않으면 null.
ProtocolFrame? parseProtocolFrame(List<int> raw) {
  if (raw.isEmpty) return null;
  List<int> data = List<int>.from(raw);
  if (data.isNotEmpty && data.first == protocolEnq.first) {
    data = data.sublist(1);
  }
  // CRLF 제거
  while (data.isNotEmpty && (data.last == 0x0D || data.last == 0x0A)) {
    data.removeLast();
  }
  // 꼬리 '@@' 제거
  if (data.length >= 2 &&
      data[data.length - 2] == protocolTail[0] &&
      data[data.length - 1] == protocolTail[1]) {
    data = data.sublist(0, data.length - 2);
  }
  // ETX 제거
  if (data.isNotEmpty && data.last == protocolEtx.first) {
    data = data.sublist(0, data.length - 1);
  }

  String text;
  try {
    text = String.fromCharCodes(data);
  } catch (_) {
    return null;
  }
  final parts = text.split(',');
  if (parts.length < 2) return null;
  final idStr = parts[0].trim();
  final count = int.tryParse(parts[1].trim());
  if (count == null) return null;
  final rawValues = count > 0
      ? parts.sublist(2, (2 + count).clamp(0, parts.length))
      : parts.sublist(2);
  final values = rawValues.map(_parseProtocolValue).toList();
  return ProtocolFrame(id: idStr, count: count, values: values);
}

/// 데모/자체검증용 — 실제 장비 프레임과 동일한 형식의 바이트 프레임 생성.
Uint8List buildProtocolFrame(String idStr, List<double> values, {bool decimal = true}) {
  String fmt(double v) {
    final sign = v < 0 ? '-' : '+';
    final av = v.abs();
    if (decimal) {
      return '$sign${av.toStringAsFixed(3)}';
    }
    return '$sign${(av * 1000).round().toString().padLeft(4, '0')}';
  }

  final count = values.length;
  final countStr = count.toString().padLeft(2, '0');
  final body = '$idStr,$countStr,${values.map(fmt).join(',')}';
  final bytes = <int>[]
    ..addAll(protocolEnq)
    ..addAll(body.codeUnits)
    ..addAll(protocolEtx)
    ..addAll(protocolTail)
    ..addAll([0x0D, 0x0A]);
  return Uint8List.fromList(bytes);
}
