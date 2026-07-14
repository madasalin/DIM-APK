import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

/// 최초 실행시에만 아이디/비번(ddtcj / ddtcj)을 물어보고, 한 번 통과하면
/// SharedPreferences에 로그인 상태를 저장해서 다음부터는 바로 메인 화면으로 간다.
class LoginScreen extends StatefulWidget {
  final Widget Function() buildHome;
  const LoginScreen({super.key, required this.buildHome});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _kLoggedInKey = "dim_logged_in";
  static const _validId = "ddtcj";
  static const _validPw = "ddtcj";

  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_kLoggedInKey) ?? false;
    setState(() {
      _loggedIn = done;
      _checking = false;
    });
  }

  Future<void> _submit() async {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (id == _validId && pw == _validPw) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLoggedInKey, true);
      setState(() {
        _loggedIn = true;
        _error = null;
      });
    } else {
      setState(() => _error = "아이디 또는 비밀번호가 올바르지 않습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loggedIn) {
      return widget.buildHome();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', width: 120, height: 120),
                const SizedBox(height: 16),
                const Text("DIM",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.titleColor)),
                const Text("4CH 측정 프로그램", style: TextStyle(fontSize: 13, color: AppColors.neutral)),
                const SizedBox(height: 32),
                TextField(
                  controller: _idCtrl,
                  decoration: const InputDecoration(labelText: "아이디", border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pwCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: "비밀번호",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 12)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                    onPressed: _submit,
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("로그인")),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
