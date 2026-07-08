import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/producao_service.dart';
import '../services/auth_service.dart';
import '../app_theme.dart';

class MetasScreen extends StatefulWidget {
  final String setor;
  const MetasScreen({super.key, required this.setor});
  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final _service = ProducaoService();
  final _auth = AuthService();
  List<String> _funcionarios = [];
  Map<String, int> _metasAtuais = {};
  final Map<String, TextEditingController> _ctrls = {};
  bool _loading = true;
  bool _saving = false;
  String? _msg;
  bool _msgErro = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final funcs = await _service.getFuncionariosSetor(widget.setor);
    final metasSnap = await _service
        .watchMetasSetor(widget.setor)
        .first;

    for (final f in funcs) {
      _ctrls[f] = TextEditingController(
          text: metasSnap[f]?.toString() ?? '');
    }
    if (mounted) setState(() {
      _funcionarios = funcs;
      _metasAtuais = metasSnap;
      _loading = false;
    });
  }

  Future<void> _salvar() async {
    setState(() { _saving = true; _msg = null; });
    final email = _auth.currentUser?.email ?? 'desconhecido';
    int salvos = 0;
    for (final f in _funcionarios) {
      final val = int.tryParse(_ctrls[f]?.text ?? '');
      if (val != null && val > 0) {
        await _service.salvarMeta(
          funcionario: f,
          setor: widget.setor,
          meta: val,
          emailGestor: email,
        );
        salvos++;
      }
    }
    if (mounted) setState(() {
      _saving = false;
      _msgErro = false;
      _msg = '$salvos meta(s) salva(s) com sucesso!';
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Metas do Dia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary, fontFamily: 'Inter')),
          Text('Setor: ${widget.setor}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Inter')),
        ]),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await _auth.logout();
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.logout, size: 16, color: AppTheme.textSecondary),
            label: const Text('Sair', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Inter')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accentBlue.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 16, color: AppTheme.accentBlue),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Define a meta individual de cada funcionário para hoje. '
                        'Alterações são refletidas em tempo real no painel.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.accentBlue, fontFamily: 'Inter'),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  if (_funcionarios.isEmpty)
                    const Center(child: Text('Nenhum funcionário encontrado hoje.',
                        style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Inter')))
                  else
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ListView.separated(
                            itemCount: _funcionarios.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: AppTheme.border),
                            itemBuilder: (_, i) {
                              final f = _funcionarios[i];
                              final metaAtual = _metasAtuais[f];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(f,
                                            style: const TextStyle(
                                              fontSize: 14, fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary, fontFamily: 'Inter',
                                            )),
                                        if (metaAtual != null && metaAtual > 0)
                                          Text('Meta atual: $metaAtual peças',
                                              style: const TextStyle(
                                                fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'Inter',
                                              )),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      controller: _ctrls[f],
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary, fontFamily: 'Inter',
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                                        suffixText: 'pç',
                                        suffixStyle: const TextStyle(
                                            fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'Inter'),
                                        filled: true,
                                        fillColor: AppTheme.surfaceElevated,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                    ),
                                  ),
                                ]),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Mensagem feedback
                  if (_msg != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_msgErro ? AppTheme.accentRed : AppTheme.accentGreen).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (_msgErro ? AppTheme.accentRed : AppTheme.accentGreen).withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Icon(_msgErro ? Icons.error_outline : Icons.check_circle_outline,
                            size: 16,
                            color: _msgErro ? AppTheme.accentRed : AppTheme.accentGreen),
                        const SizedBox(width: 8),
                        Text(_msg!,
                            style: TextStyle(
                              fontSize: 12, fontFamily: 'Inter',
                              color: _msgErro ? AppTheme.accentRed : AppTheme.accentGreen,
                            )),
                      ]),
                    ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _salvar,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'Salvando...' : 'Salvar Metas',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
