class Turma {
  final int idTurma;
  final String nomeTurma;
  final String? serie;
  final String? periodo;
  final int totalAlunos;

  Turma({
    required this.idTurma,
    required this.nomeTurma,
    this.serie,
    this.periodo,
    this.totalAlunos = 0,
  });

  factory Turma.fromJson(Map<String, dynamic> json) {
    return Turma(
      // int.tryParse evita crash caso o Laravel retorne o id como string
      idTurma: int.tryParse(
            (json['id_turma'] ?? json['id'] ?? json['idTurma'] ?? 0).toString(),
          ) ??
          0, 
      nomeTurma: (json['nome_turma'] ?? json['nome'] ?? json['turma'] ?? 'Turma').toString(),
      serie: json['serie']?.toString(),
      periodo: json['periodo']?.toString(),
      totalAlunos: int.tryParse(
            (json['total_alunos'] ?? json['alunos_count'] ?? 0).toString(),
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_turma': idTurma,
      'nome_turma': nomeTurma,
      'serie': serie,
      'periodo': periodo,
      'total_alunos': totalAlunos,
    };
  }
}
