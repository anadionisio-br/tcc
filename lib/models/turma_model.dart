class Turma {
  final int idTurma;
  final String nomeTurma;
  final String? serie;
  final String? periodo;

  Turma({
    required this.idTurma,
    required this.nomeTurma,
    this.serie,
    this.periodo,
  });

  factory Turma.fromJson(Map<String, dynamic> json) {
    return Turma(
      idTurma: json['id_turma'],
      nomeTurma: json['nome_turma'] ?? '',
      serie: json['serie'],
      periodo: json['periodo'],
    );
  }
}