import 'package:flutter/material.dart';
import 'measurement_controller.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/channel_chart.dart';
import 'widgets/value_card.dart';

class HomeScreen extends StatefulWidget {
  final MeasurementController controller;
  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _engineerMode = false;

  MeasurementController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _openSettings() async {
    if (c.isScanning) {
      _snack("스캔 중에는 환경설정을 바꿀 수 없습니다. 스캔을 먼저 멈춰 주세요.");
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(controller: c)));
    setState(() {});
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _doZero() async {
    final (ok, msg) = await c.doZero();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ok ? "영점설정" : "영점설정 — 확인 필요"),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("확인"))],
      ),
    );
  }

  Future<void> _doClear() async {
    final (ok, msg) = await c.doClear();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ok ? "영점 초기화" : "영점 초기화 — 확인 필요"),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("확인"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = c.serial.isConnected;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 24, height: 24),
            const SizedBox(width: 8),
            const Text("DIM", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.titleColor)),
            const SizedBox(width: 8),
            Icon(Icons.usb, size: 16, color: connected ? AppColors.pass : AppColors.neutral),
          ],
        ),
        actions: [
          IconButton(onPressed: _openSettings, icon: const Icon(Icons.settings)),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // ── R1~R4 값 카드 (2x2) ──
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: chNames.map((ch) {
                  final tol = c.settings.tol[ch] ?? [0.0, 100.0];
                  final extra = ch == "R4" && c.r4Regions.isNotEmpty
                      ? " (Deflector ${c.r4DeflectorEvents}개/${c.removedR4.length}점 제거"
                          "${c.r4CountOk == false ? ' ⚠재측정' : ''})"
                      : "";
                  return ValueCard(
                    name: ch,
                    value: c.lastValues[ch],
                    pass: c.lastPass[ch],
                    sampleCount: c.buffers[ch]?.length ?? 0,
                    tol: tol,
                    extra: extra,
                    isGroove: ch == "R4",
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // ── 컨트롤 ──
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.isScanning ? AppColors.fail : AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => c.toggleScan(),
                      child: Text(c.isScanning ? "스캔중... (클릭 시 중단)" : "스캔시작"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.zeroBtn, foregroundColor: Colors.white),
                      onPressed: c.isScanning ? null : _doZero,
                      child: const Text("MZERO"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: c.isScanning ? null : _doClear,
                      child: const Text("MCLEAR"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("스캔시간(초):"),
                  Expanded(
                    child: Slider(
                      value: c.settings.scanDurationSec.clamp(0.2, 60.0).toDouble(),
                      min: 0.2,
                      max: 60.0,
                      onChanged: c.isScanning
                          ? null
                          : (v) {
                              setState(() => c.settings.scanDurationSec = v);
                              c.settings.save();
                            },
                    ),
                  ),
                  SizedBox(width: 42, child: Text(c.settings.scanDurationSec.toStringAsFixed(1))),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: c.isScanning && c.mode == ScanMode.real ? null : () => c.toggleDemoProtocol(),
                      child: Text(c.isScanning && c.mode == ScanMode.demo ? "데모 송출 중... (클릭 시 중단)" : "데모 송출 테스트 (통신 포맷)"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Text("엔지니어 모드", style: TextStyle(fontSize: 12)),
                      Switch(value: _engineerMode, onChanged: (v) => setState(() => _engineerMode = v)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerLeft, child: Text(c.status, style: const TextStyle(fontSize: 12, color: AppColors.neutral))),
              const SizedBox(height: 6),

              // ── 엔지니어 모드: R1~R4 그래프 ──
              if (_engineerMode)
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      ChannelChart(title: "R1", data: c.buffers["R1"] ?? []),
                      ChannelChart(title: "R2", data: c.buffers["R2"] ?? []),
                      ChannelChart(title: "R3", data: c.buffers["R3"] ?? []),
                      ChannelChart(
                        title: "R4 (원본, 빨강=제거, 노랑=이상 정점)",
                        data: c.buffers["R4"] ?? [],
                        removedIdx: c.removedR4,
                        peakIdx: c.r4Regions.map((r) => r.peakIdx).toList(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
