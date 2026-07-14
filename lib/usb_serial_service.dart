// ════════════════════════════════════════════════════════════════
//  FTDI(및 CP210x/CH34x/PL2303/CDC-ACM) USB OTG 시리얼 통신 래퍼
//  데스크톱 SerialWorker의 원칙(메인 스레드에서 read() 금지, 라인 단위
//  버퍼링, 포트 끊김 대비)을 Stream 기반으로 동일하게 지킨다.
// ════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'settings.dart';

const int ftdiVendorId = 0x0403; // FTDI 공식 VID — 장치 목록에서 우선 표시용

class UsbFtdiService {
  UsbPort? _port;
  UsbDevice? _device;
  StreamSubscription<Uint8List>? _sub;
  final List<int> _rxBuffer = [];
  final StreamController<List<int>> _frameController = StreamController.broadcast();

  Stream<List<int>> get frames => _frameController.stream;
  bool get isConnected => _port != null;
  UsbDevice? get device => _device;

  Future<List<UsbDevice>> listDevices() async {
    final devices = await UsbSerial.listDevices();
    // FTDI 칩을 목록 맨 앞으로 정렬 (선택 편의용)
    devices.sort((a, b) {
      final af = a.vid == ftdiVendorId ? 0 : 1;
      final bf = b.vid == ftdiVendorId ? 0 : 1;
      return af.compareTo(bf);
    });
    return devices;
  }

  /// 지정한 USB 장치를 열고 설정값대로 포트 파라미터를 맞춘다.
  /// 성공 시 null, 실패 시 오류 메시지를 반환한다.
  Future<String?> connect(UsbDevice device, AppSettings settings) async {
    await disconnect();
    try {
      final port = await device.create();
      if (port == null) return "포트를 생성할 수 없습니다. (드라이버 미지원 장치일 수 있음)";
      final opened = await port.open();
      if (!opened) return "포트를 열 수 없습니다. (USB 권한이 거부되었을 수 있습니다)";

      final parity = {
            "N": UsbPort.PARITY_NONE,
            "E": UsbPort.PARITY_EVEN,
            "O": UsbPort.PARITY_ODD,
          }[settings.parity] ??
          UsbPort.PARITY_NONE;
      final stopBits = settings.stopBits >= 2 ? UsbPort.STOPBITS_2 : UsbPort.STOPBITS_1;
      final dataBits = settings.dataBits == 7 ? UsbPort.DATABITS_7 : UsbPort.DATABITS_8;

      await port.setPortParameters(settings.baudRate, dataBits, stopBits, parity);
      await port.setDTR(true);
      await port.setRTS(true);

      _rxBuffer.clear();
      _sub = port.inputStream?.listen(_onRawData, onError: (_) {
        // 케이블 분리/장비 리셋 등 — disconnect()에서 정리, 상위 UI는
        // frames 스트림 타임아웃으로 "응답 없음" 상태를 감지한다.
      });
      _port = port;
      _device = device;
      return null;
    } catch (e) {
      return "연결 중 오류: $e";
    }
  }

  void _onRawData(Uint8List data) {
    _rxBuffer.addAll(data);
    // 라인(LF) 단위로 완전한 프레임이 만들어졌을 때만 내보낸다.
    // (read()가 중간에서 잘려 들어와도 안전하게 누적/파싱하기 위함)
    while (true) {
      final idx = _rxBuffer.indexOf(0x0A);
      if (idx == -1) break;
      final line = List<int>.from(_rxBuffer.sublist(0, idx + 1));
      _rxBuffer.removeRange(0, idx + 1);
      if (!_frameController.isClosed) _frameController.add(line);
    }
  }

  Future<void> writeCommand(String cmd) async {
    final p = _port;
    if (p == null) return;
    await p.write(Uint8List.fromList('$cmd\r\n'.codeUnits));
  }

  /// 명령 전송 후 ACK('A'\r\n) 또는 데이터 프레임을 기다린다.
  Future<List<int>?> waitFrame({Duration timeout = const Duration(milliseconds: 1000)}) async {
    try {
      return await frames.first.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
    _device = null;
  }

  void dispose() {
    disconnect();
    _frameController.close();
  }
}
