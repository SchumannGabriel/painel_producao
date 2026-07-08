import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/producao_model.dart';
import '../services/producao_service.dart';
import '../services/auth_service.dart';
import '../widgets/donut_kpi_card.dart';
import '../widgets/tabela_producao.dart';
import '../app_theme.dart';
import 'login_screen.dart';
import 'metas_screen.dart';

class PainelProducaoScreen extends StatefulWidget {
  const PainelProducaoScreen({super.key});
  @override
  State<PainelProducaoScreen> createState() => _PainelProducaoScreenState();
}

class _PainelProducaoScreenState extends State<PainelProducaoScreen> {
  final _service = ProducaoService();
  final _auth = AuthService();

  String? _setorAtivo;
  List<String> _setores = [];
  StreamSubscription<List<String>>? _setoresSub;

  @override
  void initState() {
    super.initState();
    // Assina o stream de setores uma vez no initState
    _setoresSub = _service.watchSetoresHoje().listen((setores) {
      if (!mounted) return;
      setState(() {
        _setores = setores;
        // Mantém o setor ativo se ainda existir, senão vai pro primeiro
        if (_setorAtivo == null || !setores.contains(_setorAtivo)) {
          _setorAtivo = setores.isNotEmpty ? setores.first : null;
        }
      });
    });
  }

  @override
  void dispose() {
    _setoresSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (_setorAtivo == null)
                const Expanded(child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlue),
                ))
              else
                Expanded(child: _buildConteudo(_setorAtivo!)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final data = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
          ),
          child: const Icon(Icons.factory_outlined,
              color: AppTheme.accentBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Painel de Produção', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary, fontFamily: 'Inter')),
          Text(data, style: const TextStyle(
              fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'Inter')),
        ]),
        const SizedBox(width: 24),
        // Chips de setor
        if (_setores.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _setores.map((setor) {
                  final isAtivo = setor == _setorAtivo;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _setorAtivo = setor),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isAtivo
                              ? AppTheme.accentBlue.withOpacity(0.15)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAtivo ? AppTheme.accentBlue : AppTheme.border,
                            width: isAtivo ? 1.5 : 1,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (isAtivo) ...[
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.accentBlue)),
                            const SizedBox(width: 6),
                          ],
                          Text(setor, style: TextStyle(
                            fontSize: 13,
                            fontWeight: isAtivo ? FontWeight.w600 : FontWeight.w400,
                            color: isAtivo ? AppTheme.accentBlue : AppTheme.textSecondary,
                            fontFamily: 'Inter',
                          )),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConteudo(String setor) {
    return StreamBuilder<Map<String, int>>(
      stream: _service.watchMetasSetor(setor),
      builder: (context, metasSnap) {
        final metas = metasSnap.data ?? {};
        return StreamBuilder<List<ProducaoAtiva>>(
          stream: _service.watchSetorHoje(setor),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  color: AppTheme.accentBlue));
            }
            if (snap.hasError) {
              return Center(child: Text('Erro: ${snap.error}',
                  style: const TextStyle(color: AppTheme.accentRed,
                      fontFamily: 'Inter')));
            }

            final registros = snap.data ?? [];
            final resumo = _service.montarResumo(setor, registros, metas);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KpiRow(resumo: resumo),
                const SizedBox(height: 16),
                _buildTabelaHeader(resumo, setor),
                const SizedBox(height: 8),
                Expanded(child: TabelaProducao(key: const ValueKey('tabela'), funcionarios: resumo.funcionarios)),
                const SizedBox(height: 10),
                _buildLegenda(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTabelaHeader(ResumoSetor resumo, String setor) {
    return Row(children: [
      const Text('PRODUÇÃO POR FUNCIONÁRIO', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppTheme.textMuted, letterSpacing: 0.8, fontFamily: 'Inter')),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3), width: 0.5),
        ),
        child: Text('${resumo.funcionarios.length} funcionários',
            style: const TextStyle(fontSize: 11, color: AppTheme.accentBlue,
                fontWeight: FontWeight.w600, fontFamily: 'Inter')),
      ),
      const Spacer(),
      _LiveBadge(),
      const SizedBox(width: 12),
      StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, userSnap) {
          if (userSnap.data != null) {
            return TextButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => MetasScreen(setor: setor))),
              icon: const Icon(Icons.edit_outlined,
                  size: 14, color: AppTheme.accentYellow),
              label: const Text('Metas', style: TextStyle(fontSize: 12,
                  color: AppTheme.accentYellow, fontFamily: 'Inter')),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: AppTheme.accentYellow.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            );
          }
          return TextButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoginScreen())),
            icon: const Icon(Icons.lock_outlined, size: 14, color: AppTheme.textMuted),
            label: const Text('Gestor', style: TextStyle(fontSize: 12,
                color: AppTheme.textMuted, fontFamily: 'Inter')),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildLegenda() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _legItem(AppTheme.accentGreen, 'ATENDENDO A META'),
      const SizedBox(width: 28),
      _legItem(AppTheme.accentYellow, 'ATENÇÃO'),
      const SizedBox(width: 28),
      _legItem(AppTheme.accentRed, 'ABAIXO DA META'),
    ]);
  }

  Widget _legItem(Color cor, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cor)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w600, color: cor,
            letterSpacing: 0.8, fontFamily: 'Inter')),
      ]);
}

// ── KPI Row ───────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final ResumoSetor resumo;
  const _KpiRow({required this.resumo});

  @override
  Widget build(BuildContext context) {
    final pct = resumo.percentualMeta;
    final corPct = AppTheme.colorParaPercentual(pct);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          Expanded(child: _KpiItem(titulo: 'META DO DIA',
              valor: resumo.metaTotal, cor: AppTheme.accentYellow)),
          _div(),
          Expanded(child: _KpiItem(titulo: 'PRODUÇÃO DO DIA',
              valor: resumo.producaoTotal, cor: AppTheme.accentGreen)),
          _div(),
          Expanded(child: _RelogioKpi()),
          _div(),
          DonutMetaWidget(percentual: pct, cor: corPct),
        ]),
      ),
    );
  }

  Widget _div() => Container(width: 1, color: AppTheme.border,
      margin: const EdgeInsets.symmetric(horizontal: 24));
}

class _KpiItem extends StatelessWidget {
  final String titulo;
  final int valor;
  final Color cor;
  const _KpiItem({required this.titulo, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: cor, letterSpacing: 1.4, fontFamily: 'Inter')),
      const SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown,
        child: Text(_fmt(valor), style: TextStyle(fontSize: 56,
            fontWeight: FontWeight.w900, color: cor,
            fontFamily: 'Inter', height: 1.0)),
      ),
      Text('PEÇAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: cor.withOpacity(0.7), letterSpacing: 1.2, fontFamily: 'Inter')),
    ]);
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Relógio ───────────────────────────────────────────────────────────────────
class _RelogioKpi extends StatefulWidget {
  @override
  State<_RelogioKpi> createState() => _RelogioKpiState();
}
class _RelogioKpiState extends State<_RelogioKpi> {
  late DateTime _now;
  @override
  void initState() { super.initState(); _now = DateTime.now(); }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      initialData: _now,
      builder: (_, snap) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('ATUALIZADO EM', style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w700, color: AppTheme.textSecondary,
            letterSpacing: 1.2, fontFamily: 'Inter')),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown,
          child: Text(DateFormat('HH:mm').format(snap.data!),
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary, fontFamily: 'Inter', height: 1.0)),
        ),
      ]),
    );
  }
}

// ── Badge AO VIVO ─────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}
class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: AppTheme.accentGreen.withOpacity(_anim.value))),
      const SizedBox(width: 5),
      Text('AO VIVO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppTheme.accentGreen.withOpacity(_anim.value),
          letterSpacing: 1.5, fontFamily: 'Inter')),
    ]),
  );
}
