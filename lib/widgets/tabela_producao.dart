import 'package:flutter/material.dart';
import '../models/producao_model.dart';
import '../app_theme.dart';

const List<String> kHorarios = [
  '07:00','08:00','09:00','10:00','11:00','12:00',
  '13:00','14:00','15:00','16:00','17:00','17:48',
];
const List<String> kLabels = [
  '07h','08h','09h','10h','11h','12h',
  '13h','14h','15h','16h','17h','17:48',
];

class TabelaProducao extends StatefulWidget {
  final List<ProducaoAtiva> funcionarios;
  const TabelaProducao({super.key, required this.funcionarios});

  @override
  State<TabelaProducao> createState() => _TabelaProducaoState();
}

class _TabelaProducaoState extends State<TabelaProducao> {
  late List<ProducaoAtiva> _dados;

  @override
  void initState() {
    super.initState();
    _dados = widget.funcionarios;
  }

  @override
  void didUpdateWidget(TabelaProducao old) {
    super.didUpdateWidget(old);
    // Atualiza os dados sem trigger de rebuild da estrutura
    if (widget.funcionarios != old.funcionarios) {
      _dados = widget.funcionarios;
      // Não chama setState aqui — deixa o Flutter reconciliar via build normal
    }
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final horaAtual =
        '${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}';
    final idxAtual = _idxAtual(horaAtual);

    if (widget.funcionarios.isEmpty) {
      return Container(
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: const Center(
          child: Text('Nenhum funcionário registrado hoje',
              style: TextStyle(color: AppTheme.textSecondary,
                  fontFamily: 'Inter', fontSize: 14)),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      const nomeW  = 220.0;
      const metaW  = 82.0;
      const totalW = 82.0;
      const pctW   = 88.0;
      const fixedW = nomeW + metaW + totalW + pctW;
      final horaW  = ((w - fixedW) / kHorarios.length).clamp(54.0, 100.0);
      final tableW = fixedW + horaW * kHorarios.length;
      final needsScroll = tableW > w;

      final headH = w > 1200 ? 46.0 : 40.0;
      final rowH  = w > 1200 ? 54.0 : 48.0;
      final fsH   = w > 1200 ? 11.5 : 10.0;
      final fsB   = w > 1200 ? 14.5 : 13.0;

      Widget content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header (estático — não muda nunca) ──────────────────────────
          RepaintBoundary(
            child: Container(
              color: AppTheme.surfaceElevated,
              child: Row(children: [
                _hCell('FUNCIONÁRIO', nomeW, headH, fsH,
                    align: Alignment.centerLeft, pad: 16),
                _hCell('META/DIA', metaW, headH, fsH),
                ...List.generate(kHorarios.length, (i) => _hCell(
                    kLabels[i], horaW, headH, fsH,
                    destaque: i == idxAtual, bold: i == idxAtual)),
                _hCell('TOTAL', totalW, headH, fsH, bold: true),
                _hCell('% META', pctW, headH, fsH),
              ]),
            ),
          ),

          // ── Linhas — cada célula é um RepaintBoundary independente ──────
          ...widget.funcionarios.map((f) {
            final pct = f.percentualMeta;
            final cor = AppTheme.colorParaPercentual(pct);

            return RepaintBoundary(
              key: ValueKey('row_${f.funcionario}'),
              child: Container(
                decoration: BoxDecoration(border: Border(
                    top: BorderSide(color: AppTheme.border, width: 0.5))),
                child: Row(children: [
                  // Nome — estático
                  SizedBox(width: nomeW, height: rowH,
                    child: Padding(padding: const EdgeInsets.only(left: 16),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 7, height: 7,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: cor,
                                boxShadow: [BoxShadow(
                                    color: cor.withOpacity(0.5), blurRadius: 4)])),
                        const SizedBox(width: 8),
                        Flexible(child: Text(f.funcionario,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: fsB,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                fontFamily: 'Inter'))),
                      ]),
                    ),
                  ),

                  // Meta
                  _numCell(f.metaEfetiva, metaW, rowH, fsB,
                      color: AppTheme.textSecondary),

                  // Colunas horárias
                  ...List.generate(kHorarios.length, (i) {
                    final isAtual = i == idxAtual;
                    final isPast  = i < idxAtual;
                    // Hora atual → quantidade ao vivo do documento
                    // Horas passadas → snapshot horário salvo
                    final qtd = f.quantidadeNaHora(
                      kHorarios[i], null,
                      isHoraAtual: isAtual,
                    );

                    if (isAtual) {
                      // Hora atual: badge azul, atualiza em tempo real
                      return SizedBox(width: horaW, height: rowH, child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.accentBlue.withOpacity(0.5)),
                          ),
                          child: Text(qtd.toString(),
                              style: TextStyle(fontSize: fsB,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentBlue,
                                  fontFamily: 'Inter')),
                        ),
                      ));
                    }

                    return _numCell(qtd, horaW, rowH, fsB,
                        color: qtd == 0
                            ? AppTheme.textMuted
                            : isPast
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted);
                  }),

                  // Total
                  _numCell(f.quantidade, totalW, rowH, fsB, bold: true),

                  // % badge
                  SizedBox(width: pctW, height: rowH, child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: cor.withOpacity(0.35), width: 0.5),
                      ),
                      child: Text('${pct.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: fsB - 1,
                              fontWeight: FontWeight.w700,
                              color: cor, fontFamily: 'Inter')),
                    ),
                  )),
                ]),
              ),
            );
          }),
        ],
      );

      if (needsScroll) {
        content = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: tableW, child: content));
      }

      return Container(
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(12), child: content),
      );
    });
  }

  Widget _hCell(String label, double w, double h, double fs,
      {Alignment align = Alignment.center, bool destaque = false,
      bool bold = false, double pad = 4}) {
    return SizedBox(width: w, height: h,
      child: Padding(padding: EdgeInsets.symmetric(horizontal: pad),
        child: Align(alignment: align, child: Text(label, style: TextStyle(
            fontSize: fs,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: destaque ? AppTheme.accentBlue : AppTheme.textMuted,
            letterSpacing: 0.7, fontFamily: 'Inter')))));
  }

  Widget _numCell(int valor, double w, double h, double fs,
      {bool bold = false, Color? color}) {
    return SizedBox(width: w, height: h, child: Center(
      child: Text(valor == 0 ? '—' : valor.toString(), style: TextStyle(
          fontSize: fs,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? AppTheme.textPrimary,
          fontFamily: 'Inter'))));
  }

  int _idxAtual(String horaAtual) {
    final min = _toMin(horaAtual);
    // Encontra a última coluna cujo início <= hora atual
    for (int i = kHorarios.length - 1; i >= 0; i--) {
      if (min >= _toMin(kHorarios[i])) return i;
    }
    return 0;
  }

  int _toMin(String h) {
    final p = h.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}
