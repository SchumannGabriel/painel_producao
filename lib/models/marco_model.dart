import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa um "corte" de produção acumulada num horário fixo
/// (09:30, 11:30, 15:00, 16:30) ou de hora extra.
class Marco {
  final String id;
  final String horarioAlvo; // ex: "09:30"
  final String tipo; // "marco_fixo" | "hora_extra"
  final DateTime registradoEm;
  final int quantidadeAcumulada; // total desde o início do apontamento
  final int quantidadeNoPeriodo; // diferença em relação ao marco anterior

  Marco({
    required this.id,
    required this.horarioAlvo,
    required this.tipo,
    required this.registradoEm,
    required this.quantidadeAcumulada,
    required this.quantidadeNoPeriodo,
  });

  factory Marco.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Marco(
      id: doc.id,
      horarioAlvo: data['horario_alvo'] as String? ?? '',
      tipo: data['tipo'] as String? ?? 'marco_fixo',
      registradoEm: (data['registrado_em'] as Timestamp).toDate(),
      quantidadeAcumulada: data['quantidade_acumulada'] as int? ?? 0,
      quantidadeNoPeriodo: data['quantidade_no_periodo'] as int? ?? 0,
    );
  }

  bool get isHoraExtra => tipo == 'hora_extra';
}