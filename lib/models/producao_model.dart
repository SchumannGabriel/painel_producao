import 'package:cloud_firestore/cloud_firestore.dart';

class Snapshot {
  final String periodo;
  final int quantidade;
  final DateTime registradoEm;
  // "horario" = gerado pela Cloud Function a cada hora
  // null ou outro valor = marco fixo (09:30, 11:30 etc.) do outro relatório
  final String? tipo;

  Snapshot({
    required this.periodo,
    required this.quantidade,
    required this.registradoEm,
    this.tipo,
  });

  factory Snapshot.fromMap(Map<String, dynamic> map) {
    return Snapshot(
      periodo: map['periodo'] ?? '',
      quantidade: (map['quantidade'] ?? 0).toInt(),
      registradoEm: map['registrado_em'] is Timestamp
          ? (map['registrado_em'] as Timestamp).toDate()
          : DateTime.now(),
      tipo: map['tipo'] as String?,
    );
  }
}

class MetaFuncionario {
  final String funcionario;
  final String setor;
  final int meta;
  final DateTime atualizadoEm;
  final String atualizadoPor;

  MetaFuncionario({
    required this.funcionario,
    required this.setor,
    required this.meta,
    required this.atualizadoEm,
    required this.atualizadoPor,
  });

  factory MetaFuncionario.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MetaFuncionario(
      funcionario: data['funcionario'] ?? '',
      setor: data['setor'] ?? '',
      meta: (data['meta'] ?? 0).toInt(),
      atualizadoEm: data['atualizado_em'] is Timestamp
          ? (data['atualizado_em'] as Timestamp).toDate()
          : DateTime.now(),
      atualizadoPor: data['atualizado_por'] ?? '',
    );
  }
}

class ProducaoAtiva {
  final String id;
  final String ordem;
  final int quantidade;
  final int meta;
  final String funcionario;
  final String setor;
  final String status;
  final DateTime? inicio;
  final DateTime? atualizadoEm;
  final DateTime? finalizadoEm;
  final List<Snapshot> snapshots;        // marcos de apontamento — NUNCA tocar
  final List<Snapshot> snapshotsHorario; // só do painel de produção
  int metaGestor;

  ProducaoAtiva({
    required this.id,
    required this.ordem,
    required this.quantidade,
    required this.meta,
    required this.funcionario,
    required this.setor,
    required this.status,
    this.inicio,
    this.atualizadoEm,
    this.finalizadoEm,
    required this.snapshots,
    List<Snapshot>? snapshotsHorario,
    int? metaGestor,
  })  : snapshotsHorario = snapshotsHorario ?? const [],
        metaGestor = metaGestor ?? meta;

  int get metaEfetiva => metaGestor > 0 ? metaGestor : meta;

  factory ProducaoAtiva.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // snapshots de apontamento — sempre lidos, nunca escritos pelo painel
    List<Snapshot> snaps = [];
    if (data['snapshots'] != null) {
      final rawSnaps = data['snapshots'] as List<dynamic>;
      snaps = rawSnaps
          .map((s) => Snapshot.fromMap(s as Map<String, dynamic>))
          .toList();
    }

    // snapshots_horario — campo separado, exclusivo do painel de produção
    List<Snapshot> snapsHorario = [];
    if (data['snapshots_horario'] != null) {
      final rawSnapsH = data['snapshots_horario'] as List<dynamic>;
      snapsHorario = rawSnapsH
          .map((s) => Snapshot.fromMap(s as Map<String, dynamic>))
          .toList();
    }

    return ProducaoAtiva(
      id: doc.id,
      ordem: data['ordem']?.toString() ?? '',
      quantidade: (data['quantidade'] ?? 0).toInt(),
      meta: (data['meta'] ?? 0).toInt(),
      funcionario: data['funcionario'] ?? '',
      setor: data['setor'] ?? '',
      status: data['status'] ?? '',
      inicio: data['inicio'] is Timestamp
          ? (data['inicio'] as Timestamp).toDate()
          : null,
      atualizadoEm: data['atualizado_em'] is Timestamp
          ? (data['atualizado_em'] as Timestamp).toDate()
          : null,
      finalizadoEm: data['finalizado_em'] is Timestamp
          ? (data['finalizado_em'] as Timestamp).toDate()
          : null,
      snapshots: snaps,
      snapshotsHorario: snapsHorario,
    );
  }

  /// Quantidade acumulada ATÉ uma hora — para relatórios
  int quantidadeAteHora(String horaAlvo) {
    if (snapshots.isEmpty) return 0;
    final sorted = List<Snapshot>.from(snapshots)
      ..sort((a, b) => a.periodo.compareTo(b.periodo));
    Snapshot? melhor;
    for (final snap in sorted) {
      if (_toMin(snap.periodo) <= _toMin(horaAlvo)) melhor = snap;
    }
    return melhor?.quantidade ?? 0;
  }

  /// Retorna a quantidade produzida NAQUELA hora específica (não acumulada).
  ///
  /// O SnapshotService salva o acumulado ao FIM de cada hora:
  ///   snapshot "07:00" é salvo quando bate 08:00
  ///   snapshot "08:00" é salvo quando bate 09:00 etc.
  ///
  /// Delta de horas passadas:
  ///   07h = snapshot["07:00"] - âncora anterior
  ///   08h = snapshot["08:00"] - snapshot["07:00"]
  ///
  /// Resiliente a falhas: se o snapshot de uma hora não foi salvo a tempo
  /// (ex: app fechado, atraso de rede), a âncora anterior recua até achar
  /// o snapshot horário mais recente já existente, ou 0 se nenhum existir.
  /// Isso evita que toda a produção "pulada" caia inteira na coluna seguinte.
  ///
  /// Hora atual (ao vivo):
  ///   13h = quantidade_atual - última âncora conhecida
  int quantidadeNaHora(String horaColuna, String? _ignorado,
      {bool isHoraAtual = false}) {
    const horarios = [
      '07:00','08:00','09:00','10:00','11:00','12:00',
      '13:00','14:00','15:00','16:00','17:00','17:48',
    ];

    final idx = horarios.indexOf(horaColuna);

    if (isHoraAtual) {
      final acumuladoAnterior = _ancoraAnterior(horarios, idx);
      final diff = quantidade - acumuladoAnterior;
      return diff > 0 ? diff : 0;
    }

    // Horas passadas: se não tem snapshot salvo dessa hora, não mostra nada
    // (a produção dela será refletida quando o snapshot for criado)
    final acumuladoAtual = _snapshotHorario(horaColuna);
    if (acumuladoAtual == 0 && !_temSnapshot(horaColuna)) return 0;

    final acumuladoAnterior = _ancoraAnterior(horarios, idx);
    final diff = acumuladoAtual - acumuladoAnterior;
    return diff > 0 ? diff : 0;
  }

  /// Recua pelas horas anteriores até achar o snapshot horário mais recente
  /// já salvo. Evita usar 0 como âncora quando, na verdade, existe um
  /// snapshot mais antigo ainda válido (ex: 07:00 não foi salvo, mas existe
  /// um snapshot de marco do dia anterior — nesse caso ainda cai pra 0,
  /// pois snapshots não cruzam dias).
  int _ancoraAnterior(List<String> horarios, int idxAtual) {
    for (int i = idxAtual - 1; i >= 0; i--) {
      if (_temSnapshot(horarios[i])) {
        return _snapshotHorario(horarios[i]);
      }
    }
    return 0;
  }

  bool _temSnapshot(String periodo) {
    return snapshotsHorario.any((s) => s.periodo == periodo);
  }

  /// Retorna o valor acumulado do snapshot horário salvo.
  /// Lê de `snapshotsHorario` — campo totalmente separado de `snapshots`
  /// (apontamento), nunca cruza com ele.
  int _snapshotHorario(String periodo) {
    for (final snap in snapshotsHorario) {
      if (snap.periodo == periodo) return snap.quantidade;
    }
    return 0;
  }

  int _toMin(String hora) {
    final parts = hora.split(':');
    return int.parse(parts[0]) * 60 +
        (parts.length > 1 ? int.parse(parts[1]) : 0);
  }

  double get percentualMeta =>
      metaEfetiva > 0 ? (quantidade / metaEfetiva) * 100 : 0;
}

class ResumoSetor {
  final String setor;
  final int metaTotal;
  final int producaoTotal;
  final List<ProducaoAtiva> funcionarios;

  ResumoSetor({
    required this.setor,
    required this.metaTotal,
    required this.producaoTotal,
    required this.funcionarios,
  });

  double get percentualMeta =>
      metaTotal > 0 ? (producaoTotal / metaTotal) * 100 : 0;
}
