import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usb_serial/usb_serial.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'measurement_controller.dart';
import 'settings.dart';
import 'theme.dart';
import 'usb_serial_service.dart';

class SettingsScreen extends StatefulWidget {
  final MeasurementController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _s;
  List<UsbDevice> _devices = [];
  UsbDevice? _selected;
  String? _connectMsg;
  bool _connecting = false;

  final _zeroCtrl = TextEditingController();
  final _clearCtrl = TextEditingController();
  final _idCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _s = widget.controller.settings;
    _zeroCtrl.text = _s.zeroCmd;
    _clearCtrl.text = _s.clearCmd;
    _idCtrl.text = _s.deviceId;
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    final list = await widget.controller.serial.listDevices();
    setState(() => _devices = list);
  }

  Future<void> _connect() async {
    if (_selected == null) return;
    setState(() => _connecting = true);
    final err = await widget.controller.serial.connect(_selected!, _s);
    setState(() {
      _connecting = false;
      _connectMsg = err ?? "연결됨: ${_selected!.deviceName} (VID:${_selected!.vid}, PID:${_selected!.pid})";
    });
  }

  Future<void> _disconnect() async {
    await widget.controller.serial.disconnect();
    setState(() => _connectMsg = "연결 해제됨");
  }

  void _saveAndClose() {
    _s.zeroCmd = _zeroCtrl.text.trim().isEmpty ? "MZERO" : _zeroCtrl.text.trim();
    _s.clearCmd = _clearCtrl.text.trim().isEmpty ? "MCLEAR" : _clearCtrl.text.trim();
    _s.deviceId = _idCtrl.text.trim().isEmpty ? "01" : _idCtrl.text.trim();
    _s.save();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.controller.serial.isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text("환경설정")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("USB OTG 장치 (FTDI 등)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<UsbDevice>(
                  isExpanded: true,
                  value: _selected,
                  hint: const Text("장치 선택"),
                  items: _devices
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                              "${d.deviceName} (VID:${d.vid}${d.vid == ftdiVendorId ? ' FTDI' : ''}, PID:${d.pid})",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selected = v),
                ),
              ),
              IconButton(onPressed: _refreshDevices, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _connecting || _selected == null ? null : _connect,
                child: Text(_connecting ? "연결 중..." : "연결"),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: connected ? _disconnect : null, child: const Text("연결 해제")),
              const SizedBox(width: 8),
              Icon(Icons.circle, size: 10, color: connected ? AppColors.pass : AppColors.fail),
              const SizedBox(width: 4),
              Text(connected ? "연결됨" : "미연결", style: const TextStyle(fontSize: 12)),
            ],
          ),
          if (_connectMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_connectMsg!, style: const TextStyle(fontSize: 12, color: AppColors.neutral)),
            ),
          const Divider(height: 32),

          const Text("통신 파라미터", style: TextStyle(fontWeight: FontWeight.bold)),
          _numRow("Baudrate", _s.baudRate.toDouble(), 1200, 115200, (v) => setState(() => _s.baudRate = v.round())),
          Row(
            children: [
              const Text("Data bits:"),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _s.dataBits,
                items: const [7, 8].map((e) => DropdownMenuItem(value: e, child: Text("$e"))).toList(),
                onChanged: (v) => setState(() => _s.dataBits = v ?? 8),
              ),
              const SizedBox(width: 24),
              const Text("Parity:"),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _s.parity,
                items: const ["N", "E", "O"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _s.parity = v ?? "N"),
              ),
              const SizedBox(width: 24),
              const Text("Stop bits:"),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _s.stopBits,
                items: const [1, 2].map((e) => DropdownMenuItem(value: e, child: Text("$e"))).toList(),
                onChanged: (v) => setState(() => _s.stopBits = v ?? 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _idCtrl, decoration: const InputDecoration(labelText: "장비 ID (프레임 ID 필드, 기본 01)")),
          const SizedBox(height: 8),
          TextField(controller: _zeroCtrl, decoration: const InputDecoration(labelText: "영점설정 명령어 (MZERO)")),
          const SizedBox(height: 8),
          TextField(controller: _clearCtrl, decoration: const InputDecoration(labelText: "영점 초기화 명령어 (MCLEAR)")),
          const Divider(height: 32),

          const Text("측정 파라미터 (R4 Deflector 검출)", style: TextStyle(fontWeight: FontWeight.bold)),
          _numRow("기본 스캔시간(초)", _s.scanDurationSec, 0.2, 60.0, (v) => setState(() => _s.scanDurationSec = v), decimals: 1),
          _numRow("deriv_k (1차 임계값·이상치 감지 민감도)", _s.derivK, 1.0, 10.0, (v) => setState(() => _s.derivK = v), decimals: 1),
          _numRow("recovery_k (2차 임계값·정상 복귀 기준)", _s.recoveryK, 0.5, 10.0, (v) => setState(() => _s.recoveryK = v), decimals: 1),
          _numRow("min_drop (최소 낙차·노이즈 무시 기준)", _s.minDrop, 0.0, 5.0, (v) => setState(() => _s.minDrop = v), decimals: 2),
          _numRow("edge_margin (골 앞/뒤 추가 제거 샘플)", _s.edgeMargin.toDouble(), 0, 5, (v) => setState(() => _s.edgeMargin = v.round())),
          const SizedBox(height: 8),
          const Text("디플렉터 개수 검증", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          _numRow("기대 디플렉터 개수", _s.expectedDeflectorCount.toDouble(), 1, 10, (v) => setState(() => _s.expectedDeflectorCount = v.round())),
          _numRow("event_merge_gap (같은 디플렉터로 묶는 간격)", _s.eventMergeGap.toDouble(), 1, 60, (v) => setState(() => _s.eventMergeGap = v.round())),
          Row(
            children: [
              Expanded(
                child: Text(
                  "구간 힌트 사용 (지정 상대구간 밖은 무시)",
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Switch(value: _s.useZoneHints, onChanged: (v) => setState(() => _s.useZoneHints = v)),
            ],
          ),
          const Divider(height: 32),

          const Text("채널별 공차", style: TextStyle(fontWeight: FontWeight.bold)),
          for (final ch in chNames) _tolRow(ch),

          const SizedBox(height: 24),
          ElevatedButton(onPressed: _saveAndClose, child: const Text("저장하고 닫기")),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("dim_logged_in", false);
              if (!mounted) return;
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(buildHome: () => HomeScreen(controller: widget.controller)),
                ),
                (route) => false,
              );
            },
            child: const Text("로그아웃"),
          ),
        ],
      ),
    );
  }

  Widget _numRow(String label, double value, double min, double max, ValueChanged<double> onChanged, {int decimals = 0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 90,
            child: TextFormField(
              initialValue: decimals == 0 ? value.round().toString() : value.toStringAsFixed(decimals),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onFieldSubmitted: (t) {
                final v = double.tryParse(t);
                if (v != null) onChanged(v.clamp(min, max));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tolRow(String ch) {
    final tol = _s.tol[ch] ?? [0.0, 100.0];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text(ch, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Text("하한:"),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: tol[0].toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onFieldSubmitted: (t) {
                final v = double.tryParse(t);
                if (v != null) setState(() => _s.tol[ch] = [v, tol[1]]);
              },
            ),
          ),
          const SizedBox(width: 12),
          const Text("상한:"),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: tol[1].toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              onFieldSubmitted: (t) {
                final v = double.tryParse(t);
                if (v != null) setState(() => _s.tol[ch] = [tol[0], v]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
