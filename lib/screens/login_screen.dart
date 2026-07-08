import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _erro;
  bool _showSenha = false;

  Future<void> _login() async {
    setState(() { _loading = true; _erro = null; });
    final erro = await _auth.login(_emailCtrl.text, _senhaCtrl.text);
    if (!mounted) return;
    if (erro == null) {
      Navigator.of(context).pop(); // login ok — volta pro painel
    } else {
      setState(() { _loading = false; _erro = erro; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.factory_outlined,
                      color: AppTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Acesso Restrito',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary, fontFamily: 'Inter',
                    )),
              ]),
              const SizedBox(height: 6),
              const Text('Gestores e administradores',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Inter')),
              const SizedBox(height: 32),
              _label('E-MAIL'),
              const SizedBox(height: 6),
              _field(_emailCtrl, hint: 'gestor@empresa.com', obscure: false),
              const SizedBox(height: 16),
              _label('SENHA'),
              const SizedBox(height: 6),
              _field(_senhaCtrl, hint: '••••••••', obscure: !_showSenha,
                suffix: IconButton(
                  icon: Icon(_showSenha ? Icons.visibility_off : Icons.visibility,
                      size: 16, color: AppTheme.textMuted),
                  onPressed: () => setState(() => _showSenha = !_showSenha),
                )),
              if (_erro != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 14, color: AppTheme.accentRed),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_erro!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.accentRed, fontFamily: 'Inter'))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Entrar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: AppTheme.textMuted, letterSpacing: 0.8, fontFamily: 'Inter'));

  Widget _field(TextEditingController ctrl,
      {required String hint, required bool obscure, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      onSubmitted: (_) => _login(),
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontFamily: 'Inter'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontFamily: 'Inter'),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.accentBlue, width: 1.5)),
      ),
    );
  }
}
