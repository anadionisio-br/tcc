class AlunoModel {
  final int idAluno;
  final String nome;
  String status;
  final bool temRosto;
  final bool temRostoTeste;

  AlunoModel({
    required this.idAluno,
    required this.nome,
    this.status = 'Ausente',
    this.temRosto = false,
    this.temRostoTeste = false,
  });

  factory AlunoModel.fromJson(Map<String, dynamic> json) {
    // Normaliza o status vindo do banco/API
    final statusRaw = (json['status'] ?? '').toString().trim().toLowerCase();
    
    String statusFormatado = 'Ausente';
    if (statusRaw == 'presente') {
      statusFormatado = 'Presente';
    } else if (statusRaw == 'ausente' || statusRaw == 'falta') {
      statusFormatado = 'Ausente';
    } else if (json['status'] != null && json['status'].toString().isNotEmpty) {
      // Caso a API retorne algo como 'Presente' com P maiúsculo
      statusFormatado = json['status'].toString();
    }

    return AlunoModel(
      idAluno: int.tryParse(
            (json['id_aluno'] ?? json['idAluno'] ?? json['id'] ?? 0).toString(),
          ) ??
          0,
      nome: json['nome_aluno'] ?? json['nome'] ?? 'Aluno sem nome',
      status: statusFormatado,
      temRosto: json['tem_rosto'] == true || json['tem_rosto'].toString() == '1',
      temRostoTeste: json['tem_rosto_teste'] == true || json['tem_rosto_teste'].toString() == '1',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_aluno': idAluno,
      'nome_aluno': nome,
      'status': status,
      'tem_rosto': temRosto,
      'tem_rosto_teste': temRostoTeste,
    };
  }
}