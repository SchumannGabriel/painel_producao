import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producao_model.dart';

class ProducaoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Metas ──────────────────────────────────────────────────────────────────

  /// Stream de metas por funcionário de um setor
  Stream<Map<String, int>> watchMetasSetor(String setor) {
    return _db
        .collection('metas_funcionarios')
        .where('setor', isEqualTo: setor)
        .snapshots()
        .map((snap) {
      final map = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        map[data['funcionario'] as String] = (data['meta'] ?? 0) as int;
      }
      return map;
    });
  }

  /// Salva/atualiza meta de um funcionário
  Future<void> salvarMeta({
    required String funcionario,
    required String setor,
    required int meta,
    required String emailGestor,
  }) async {
    // ID = setor_funcionario (sem espaços)
    final id =
        '${setor}_$funcionario'.replaceAll(' ', '_').toLowerCase();
    await _db.collection('metas_funcionarios').doc(id).set({
      'funcionario': funcionario,
      'setor': setor,
      'meta': meta,
      'atualizado_em': FieldValue.serverTimestamp(),
      'atualizado_por': emailGestor,
    }, SetOptions(merge: true));
  }

  /// Busca todos os funcionários distintos de um setor (de hoje)
  Future<List<String>> getFuncionariosSetor(String setor) async {
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
    final snap = await _db
        .collection('producao_ativa')
        .where('setor', isEqualTo: setor)
        .get();
    final nomes = snap.docs
        .map((d) => ProducaoAtiva.fromDoc(d))
        .where((r) =>
            r.inicio != null && r.inicio!.isAfter(inicioDia))
        .map((r) => r.funcionario)
        .toSet()
        .toList()
      ..sort();
    return nomes;
  }

  // ── Produção ───────────────────────────────────────────────────────────────

  Stream<List<ProducaoAtiva>> watchSetorHoje(String setor) {
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
    final fimDia =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

    return _db
        .collection('producao_ativa')
        .where('setor', isEqualTo: setor)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ProducaoAtiva.fromDoc(doc))
            .where((r) =>
                r.inicio != null &&
                r.inicio!.isAfter(inicioDia) &&
                r.inicio!.isBefore(fimDia))
            .toList());
  }

  Stream<List<String>> watchSetoresHoje() {
    final hoje = DateTime.now();
    final inicioDia = DateTime(hoje.year, hoje.month, hoje.day);
    final fimDia =
        DateTime(hoje.year, hoje.month, hoje.day, 23, 59, 59);

    return _db.collection('producao_ativa').snapshots().map((snap) {
      final setores = snap.docs
          .map((doc) => ProducaoAtiva.fromDoc(doc))
          .where((r) =>
              r.inicio != null &&
              r.inicio!.isAfter(inicioDia) &&
              r.inicio!.isBefore(fimDia))
          .map((r) => r.setor)
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return setores;
    });
  }

  /// Monta o resumo do setor aplicando as metas do gestor
  ResumoSetor montarResumo(
    String setor,
    List<ProducaoAtiva> registros,
    Map<String, int> metasGestor,
  ) {
    final Map<String, List<ProducaoAtiva>> porFuncionario = {};
    for (final r in registros) {
      porFuncionario.putIfAbsent(r.funcionario, () => []).add(r);
    }

    final funcionariosConsolidados =
        porFuncionario.entries.map((entry) {
      final regs = entry.value;
      final metaFirebase = regs.fold<int>(0, (s, r) => s + r.meta);
      final qtdTotal = regs.fold<int>(0, (s, r) => s + r.quantidade);
      final snapshotsMesclados = _mesclar(regs.map((r) => r.snapshots));
      final snapshotsHorarioMesclados =
          _mesclar(regs.map((r) => r.snapshotsHorario));
      final metaGestor = metasGestor[entry.key] ?? 0;

      return ProducaoAtiva(
        id: regs.first.id,
        ordem: regs.map((r) => r.ordem).join(', '),
        quantidade: qtdTotal,
        meta: metaFirebase,
        funcionario: entry.key,
        setor: setor,
        status: regs.first.status,
        inicio: regs.first.inicio,
        snapshots: snapshotsMesclados,
        snapshotsHorario: snapshotsHorarioMesclados,
        metaGestor: metaGestor > 0 ? metaGestor : metaFirebase,
      );
    }).toList()
          ..sort((a, b) => a.funcionario.compareTo(b.funcionario));

    final metaTotal = funcionariosConsolidados
        .fold<int>(0, (s, r) => s + r.metaEfetiva);
    final prodTotal =
        funcionariosConsolidados.fold<int>(0, (s, r) => s + r.quantidade);

    return ResumoSetor(
      setor: setor,
      metaTotal: metaTotal,
      producaoTotal: prodTotal,
      funcionarios: funcionariosConsolidados,
    );
  }

  /// Mescla listas de snapshots (de múltiplas OFs de um funcionário),
  /// somando quantidades de mesmo período. Função genérica — usada tanto
  /// para `snapshots` (apontamento) quanto `snapshotsHorario` (painel),
  /// sem nunca misturar os dois.
  List<Snapshot> _mesclar(Iterable<List<Snapshot>> listas) {
    final Map<String, int> qtdPorPeriodo = {};
    for (final lista in listas) {
      for (final s in lista) {
        qtdPorPeriodo[s.periodo] = (qtdPorPeriodo[s.periodo] ?? 0) + s.quantidade;
      }
    }
    return qtdPorPeriodo.entries
        .map((e) => Snapshot(
              periodo: e.key,
              quantidade: e.value,
              registradoEm: DateTime.now(),
            ))
        .toList()
      ..sort((a, b) => a.periodo.compareTo(b.periodo));
  }
}