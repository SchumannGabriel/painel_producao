import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Gerencia os snapshots horários para o painel de produção.
///
///  REGRA DE OURO — ISOLAMENTO TOTAL DO APONTAMENTO:
/// Este serviço NUNCA escreve no array `snapshots` (usado pelo relatório
/// de apontamento com marcos fixos: 09:30, 11:30, 15:00, 16:30).
/// Ele escreve exclusivamente no campo `snapshots_horario`, separado,
/// que o relatório de apontamento nem olha. Isso garante 100% de isolamento
/// — nenhum dado criado aqui pode "vazar" para o outro relatório.
///
///  CONFIABILIDADE — SEM JANELA DE RISCO:
/// A cada verificação perguntamos: "que horas já viraram e ainda não tenho
/// snapshot salvo em snapshots_horario?" — e salvamos todas de uma vez,
/// atrasado ou não. Isso garante que nenhuma produção "some" entre horas.
///
///  IDEMPOTÊNCIA — A VERDADE É O FIRESTORE, NÃO A MEMÓRIA:
/// `_periodosJaSalvosHoje` é só uma otimização para não checar o Firestore
/// toda vez. Ela é perdida sempre que o app reinicia (refresh de página,
/// hot restart, fechar/abrir app). Por isso o `_salvarHorario` SEMPRE
/// confere no Firestore se aquele período já tem snapshot salvo antes de
/// gravar — nunca sobrescreve um snapshot já existente. Sem essa checagem,
/// um refresh de página depois da hora já fechada reescreveria o snapshot
/// histórico com a quantidade atual (errado), e a coluna "ao vivo" passaria
/// a mostrar 0 (porque a âncora anterior virou igual ao valor atual).
class SnapshotService {
  // Quando bate esse horário (já passou) → salva snapshot do período indicado
  static const _gatilhosHorario = {
    '08:00': '07:00',
    '09:00': '08:00',
    '10:00': '09:00',
    '11:00': '10:00',
    '12:00': '11:00',
    '13:00': '12:00',
    '14:00': '13:00',
    '15:00': '14:00',
    '16:00': '15:00',
    '17:00': '16:00',
    '17:48': '17:00',
    '17:50': '17:48',
  };

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _timer;

  DateTime _diaAtual = DateTime.now();
  final Set<String> _periodosJaSalvosHoje = {};

  void iniciar() {
    _verificar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _verificar());
    debugPrint('[SnapshotService] Iniciado (campo: snapshots_horario).');
  }

  void parar() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _verificar() async {
    final agora = DateTime.now();

    if (agora.day != _diaAtual.day) {
      _periodosJaSalvosHoje.clear();
      _diaAtual = agora;
    }

    final minAtual = agora.hour * 60 + agora.minute;

    for (final entry in _gatilhosHorario.entries) {
      final gatilho = entry.key;
      final periodoSalvar = entry.value;
      final minG = _toMin(gatilho);

      final jaPassou = minAtual >= minG;
      final jaFoiSalvo = _periodosJaSalvosHoje.contains(periodoSalvar);

      if (jaPassou && !jaFoiSalvo) {
        // Marca como "tratado" nesta sessão só pra evitar checagens repetidas
        // a cada 10s — a garantia real de não sobrescrever vem de dentro de
        // _salvarHorario, que confere o Firestore.
        _periodosJaSalvosHoje.add(periodoSalvar);
        debugPrint(
            '[SnapshotService] $gatilho já passou → verificando "$periodoSalvar" em snapshots_horario');
        await _salvarHorario(periodoSalvar, gatilho);
      }
    }
  }

  Future<void> _salvarHorario(String periodo, String gatilho) async {
    try {
      final hoje = DateTime.now();
      final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
      final fimDia = DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

      // Instante limite do período: hora do gatilho de hoje.
      // Ex: periodo "07:00" tem gatilho "08:00" → boundary = hoje às 08:00.
      // Só faz sentido salvar snapshot pra esse período se o apontamento
      // do funcionário já existia (já tinha 'inicio') antes desse instante.
      final gParts = gatilho.split(':');
      final boundary = DateTime(hoje.year, hoje.month, hoje.day,
          int.parse(gParts[0]), int.parse(gParts[1]));

      final snap = await _db
          .collection('producao_ativa')
          .where('inicio', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia))
          .where('inicio', isLessThanOrEqualTo: Timestamp.fromDate(fimDia))
          .get();

      if (snap.docs.isEmpty) return;

      for (final doc in snap.docs) {
        final data = doc.data();
        final quantidade = (data['quantidade'] ?? 0) as int;

        //  Se o apontamento começou DEPOIS do limite desse período, o
        // funcionário ainda nem trabalhava nessa hora — não cria snapshot
        // retroativo (senão a produção inteira "vaza" pras colunas antigas).
        final inicio = data['inicio'] is Timestamp
            ? (data['inicio'] as Timestamp).toDate()
            : null;
        if (inicio != null && inicio.isAfter(boundary)) {
          debugPrint(
              '[SnapshotService] ${data['funcionario']} começou depois de $gatilho — pulando período $periodo.');
          continue;
        }

        // Campo TOTALMENTE separado de `snapshots` — isolamento garantido
        final raw = (data['snapshots_horario'] as List<dynamic>? ?? []);
        final snapshotsHorario = raw
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();

        final idx = snapshotsHorario.indexWhere((s) => s['periodo'] == periodo);

        //  Se esse período JÁ existe no Firestore, não sobrescreve.
        // Isso é o que protege contra refresh/restart resetando a memória
        // local e regravando o snapshot histórico com a quantidade atual.
        if (idx != -1) {
          debugPrint(
              '[SnapshotService] ${data['funcionario']} — $periodo já existe, pulando (sem sobrescrever).');
          continue;
        }

        snapshotsHorario.add({
          'periodo': periodo,
          'quantidade': quantidade,
          'registrado_em': Timestamp.now(),
        });

        // Atualiza SÓ o campo snapshots_horario — nunca toca em `snapshots`
        await doc.reference.update({'snapshots_horario': snapshotsHorario});
        debugPrint(
            '[SnapshotService] ${data['funcionario']} — $periodo: $quantidade pç (snapshots_horario)');
      }
    } catch (e) {
      debugPrint('[SnapshotService] Erro ao salvar horario $periodo: $e');
      _periodosJaSalvosHoje.remove(periodo);
    }
  }

  int _toMin(String h) {
    final p = h.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }
}