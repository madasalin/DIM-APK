import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'measurement_controller.dart';
import 'settings.dart';
import 'theme.dart';
import 'usb_serial_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final serial = UsbFtdiService();
  final controller = MeasurementController(settings, serial);
  runApp(DimApp(controller: controller));
}

class DimApp extends StatelessWidget {
  final MeasurementController controller;
  const DimApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DIM — 4CH 측정 프로그램',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // 최초 실행시에만 로그인(ddtcj/ddtcj)을 거치고, 이후에는 바로 메인 화면.
      home: LoginScreen(buildHome: () => HomeScreen(controller: controller)),
    );
  }
}

