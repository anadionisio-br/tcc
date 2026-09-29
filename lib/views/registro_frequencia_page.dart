import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';

class RegistroFrequenciaPage extends StatefulWidget {
  const RegistroFrequenciaPage({super.key});

  @override
  State<RegistroFrequenciaPage> createState() => _RegistroFrequenciaPageState();
}

class _RegistroFrequenciaPageState extends State<RegistroFrequenciaPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FrequenciaController>().buscarTurmas();
    });
  }

  String _getIniciais(String nome) {
    final partes = nome.trim().split(' ');
    if (partes.isEmpty || partes[0].isEmpty) return 'A';
    if (partes.length == 1) return partes[0][0].toUpperCase();
    return '${partes[0][0]}${partes[partes.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FrequenciaController>();

    // Valida se o ID selecionado no controller realmente existe na lista de turmas
    final bool turmaExisteNaLista = controller.turmas.any(
      (t) =>
          int.tryParse(t['id_turma'].toString()) == controller.turmaSelecionada,
    );

    final int? selectedDropdownValue = turmaExisteNaLista
        ? controller.turmaSelecionada
        : null;

    return Scaffold(
      backgroundColor: SifeTheme.bgLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frequência da Turma',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: SifeTheme.textDark,
              ),
            ),
            const SizedBox(height: 20),

            // CARD DE SELEÇÃO DE TURMA E DATA
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SifeTheme.borderColor),
              ),
              child: Row(
                children: [
                  // DROPDOWN DAS TURMAS
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TURMA SELECIONADA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        controller.carregandoTurmas
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : DropdownButtonFormField<int>(
                                value: selectedDropdownValue,
                                isExpanded: true,
                                hint: const Text(
                                  'Selecione uma turma',
                                  style: TextStyle(fontSize: 14),
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                items: controller.turmas.map((turma) {
                                  final id =
                                      int.tryParse(
                                        turma['id_turma'].toString(),
                                      ) ??
                                      0;
                                  final nome =
                                      turma['nome_turma']?.toString() ??
                                      'Turma sem nome';
                                  final serie =
                                      turma['serie'] != null &&
                                          turma['serie'].toString().isNotEmpty
                                      ? ' - ${turma['serie']}'
                                      : '';

                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text(
                                      '$nome$serie',
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    controller.mudarTurma(val);
                                  }
                                },
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // SELETOR DE DATA
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DATA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          readOnly: true,
                          controller: TextEditingController(
                            text: controller.dataFormatada,
                          ),
                          decoration: InputDecoration(
                            suffixIcon: const Icon(
                              Icons.calendar_today,
                              size: 18,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onTap: () async {
                            final data = await showDatePicker(
                              context: context,
                              initialDate: controller.dataSelecionada,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (data != null) controller.mudarData(data);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // MÉTRICAS
            Row(
              children: [
                Expanded(
                  child: _buildCardMetrica(
                    'TOTAL ALUNOS',
                    '${controller.totalAlunos}',
                    Colors.black87,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCardMetrica(
                    'PRESENTES',
                    '${controller.presentes}',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCardMetrica(
                    'AUSENTES',
                    '${controller.totalAusentes}',
                    Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // LISTAGEM DOS ALUNOS
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SifeTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'ESTUDANTES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  if (controller.carregando)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: SifeTheme.primaryRed,
                        ),
                      ),
                    )
                  else if (controller.alunos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('Nenhum aluno encontrado para esta turma.'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.alunos.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final aluno = controller.alunos[index];
                        final isPresente = aluno.status == 'Presente';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPresente
                                ? Colors.green.shade100
                                : SifeTheme.primaryRedSoft,
                            child: Text(
                              _getIniciais(aluno.nome),
                              style: TextStyle(
                                color: isPresente
                                    ? Colors.green.shade800
                                    : SifeTheme.primaryRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            aluno.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Mat: ${aluno.idAluno}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: InkWell(
                            onTap: () =>
                                controller.alternarStatus(aluno.idAluno),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isPresente
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isPresente ? Colors.green : Colors.red,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPresente
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 14,
                                    color: isPresente
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    aluno.status,
                                    style: TextStyle(
                                      color: isPresente
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: controller.salvandoChamada
                          ? null
                          : () async {
                              final sucesso = await controller.salvarChamada();

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    sucesso
                                        ? 'Chamada salva com sucesso!'
                                        : 'Não foi possível salvar a chamada.',
                                  ),
                                  backgroundColor: sucesso
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              );
                            },
                      icon: controller.salvandoChamada
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        controller.salvandoChamada
                            ? 'SALVANDO...'
                            : 'SALVAR CHAMADA',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SifeTheme.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMetrica(String titulo, String valor, Color corValor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SifeTheme.borderColor),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: corValor,
            ),
          ),
        ],
      ),
    );
  }
}
