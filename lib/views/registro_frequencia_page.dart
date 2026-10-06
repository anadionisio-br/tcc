
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';

class RegistroFrequenciaPage extends StatefulWidget {
  const RegistroFrequenciaPage({super.key});

  @override
  State<RegistroFrequenciaPage> createState() =>
      _RegistroFrequenciaPageState();
}

class _RegistroFrequenciaPageState
    extends State<RegistroFrequenciaPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FrequenciaController>().buscarTurmas();
    });
  }

  String _getIniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));

    if (partes.isEmpty || partes.first.isEmpty) {
      return 'A';
    }

    if (partes.length == 1) {
      return partes.first[0].toUpperCase();
    }

    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FrequenciaController>();

    final bool turmaExisteNaLista = controller.turmas.any(
      (t) =>
          int.tryParse(t['id_turma'].toString()) ==
          controller.turmaSelecionada,
    );

    final int? selectedDropdownValue =
        turmaExisteNaLista ? controller.turmaSelecionada : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // CABEÇALHO
              // ==================================================

              _buildHeader(controller),

              const SizedBox(height: 24),

              // ==================================================
              // FILTROS
              // ==================================================

              _buildFiltros(
                context,
                controller,
                selectedDropdownValue,
              ),

              const SizedBox(height: 20),

              // ==================================================
              // INDICADORES
              // ==================================================

              _buildMetricas(controller),

              const SizedBox(height: 22),

              // ==================================================
              // LISTA DE ALUNOS
              // ==================================================

              _buildListaAlunos(controller),

              const SizedBox(height: 20),

              // ==================================================
              // BOTÃO SALVAR
              // ==================================================

              _buildBotaoSalvar(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO
  // ============================================================

  Widget _buildHeader(FrequenciaController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: SifeTheme.primaryRedSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            color: SifeTheme.primaryRed,
            size: 24,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registro de frequência',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: SifeTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Registre e acompanhe a presença dos alunos.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade400,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FILTROS
  // ============================================================

  Widget _buildFiltros(
    BuildContext context,
    FrequenciaController controller,
    int? selectedDropdownValue,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 17,
                  color: SifeTheme.textDark,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Filtros da chamada',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SifeTheme.textDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TURMA
              Expanded(
                flex: 3,
                child: _buildCampo(
                  titulo: 'TURMA',
                  child: controller.carregandoTurmas
                      ? Container(
                          height: 52,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade200,
                            ),
                          ),
                          child: const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SifeTheme.primaryRed,
                            ),
                          ),
                        )
                      : DropdownButtonFormField<int>(
                          value: selectedDropdownValue,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                          hint: const Text(
                            'Selecione uma turma',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          decoration: _inputDecoration(),
                          items: controller.turmas.map((turma) {
                            final id = int.tryParse(
                                  turma['id_turma'].toString(),
                                ) ??
                                0;

                            final nome =
                                turma['nome_turma']?.toString() ??
                                    'Turma sem nome';

                            final serie =
                                turma['serie'] != null &&
                                        turma['serie']
                                            .toString()
                                            .isNotEmpty
                                    ? ' • ${turma['serie']}'
                                    : '';

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                '$nome$serie',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            if (valor != null) {
                              controller.mudarTurma(valor);
                            }
                          },
                        ),
                ),
              ),

              const SizedBox(width: 14),

              // DATA
              Expanded(
                flex: 2,
                child: _buildCampo(
                  titulo: 'DATA',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: controller.dataSelecionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: SifeTheme.primaryRed,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (data != null) {
                        controller.mudarData(data);
                      }
                    },
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                            color: SifeTheme.primaryRed,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              controller.dataFormatada,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: SifeTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CAMPO
  // ============================================================

  Widget _buildCampo({
    required String titulo,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.blueGrey.shade400,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SifeTheme.primaryRed,
          width: 1.3,
        ),
      ),
    );
  }

  // ============================================================
  // MÉTRICAS
  // ============================================================

  Widget _buildMetricas(FrequenciaController controller) {
    return Row(
      children: [
        Expanded(
          child: _buildCardMetrica(
            titulo: 'TOTAL',
            valor: '${controller.totalAlunos}',
            icon: Icons.groups_outlined,
            cor: SifeTheme.textDark,
            fundo: const Color(0xFFF3F4F6),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildCardMetrica(
            titulo: 'PRESENTES',
            valor: '${controller.presentes}',
            icon: Icons.check_circle_outline,
            cor: Colors.green.shade700,
            fundo: Colors.green.shade50,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildCardMetrica(
            titulo: 'AUSENTES',
            valor: '${controller.totalAusentes}',
            icon: Icons.cancel_outlined,
            cor: Colors.red.shade700,
            fundo: Colors.red.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildCardMetrica({
    required String titulo,
    required String valor,
    required IconData icon,
    required Color cor,
    required Color fundo,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: fundo,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: cor,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: Colors.blueGrey.shade400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTA DE ALUNOS
  // ============================================================

  Widget _buildListaAlunos(
    FrequenciaController controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              17,
              18,
              15,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SifeTheme.primaryRedSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.groups_outlined,
                    size: 18,
                    color: SifeTheme.primaryRed,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estudantes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SifeTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${controller.totalAlunos} alunos cadastrados',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),

                if (controller.alunos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${controller.alunos.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SifeTheme.textDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: Colors.grey.shade200,
          ),

          if (controller.carregando)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: SifeTheme.primaryRed,
                ),
              ),
            )
          else if (controller.alunos.isEmpty)
            _buildEstadoVazio()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.alunos.length,
              separatorBuilder: (_, __) {
                return Divider(
                  height: 1,
                  indent: 70,
                  color: Colors.grey.shade100,
                );
              },
              itemBuilder: (context, index) {
                final aluno = controller.alunos[index];

                final bool isPresente =
                    aluno.status == 'Presente';

                return _buildAlunoItem(
                  controller,
                  aluno,
                  isPresente,
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ALUNO
  // ============================================================

  Widget _buildAlunoItem(
    FrequenciaController controller,
    dynamic aluno,
    bool isPresente,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      child: Row(
        children: [
          // AVATAR
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isPresente
                  ? Colors.green.shade50
                  : SifeTheme.primaryRedSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getIniciais(aluno.nome),
                style: TextStyle(
                  color: isPresente
                      ? Colors.green.shade700
                      : SifeTheme.primaryRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // DADOS
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  aluno.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SifeTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Matrícula: ${aluno.idAluno}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blueGrey.shade400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // STATUS
          InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: () {
              controller.alternarStatus(aluno.idAluno);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isPresente
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isPresente
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPresente
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 15,
                    color: isPresente
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isPresente ? 'Presente' : 'Ausente',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isPresente
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ESTADO VAZIO
  // ============================================================

  Widget _buildEstadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.person_off_outlined,
              color: Colors.blueGrey.shade400,
              size: 25,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nenhum aluno encontrado',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SifeTheme.textDark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Não existem alunos cadastrados para esta turma.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTÃO SALVAR
  // ============================================================

  Widget _buildBotaoSalvar(
    BuildContext context,
    FrequenciaController controller,
  ) {
    final bool salvando = controller.salvandoChamada;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SifeTheme.primaryRed,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: SifeTheme.primaryRed.withOpacity(0.18),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: salvando
              ? null
              : () async {
                  final sucesso =
                      await controller.salvarChamada();

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        content: Row(
                          children: [
                            Icon(
                              sucesso
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sucesso
                                    ? 'Chamada salva com sucesso!'
                                    : 'Não foi possível salvar a chamada.',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: sucesso
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    );
                },
          icon: salvando
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.save_outlined,
                  size: 19,
                ),
          label: Text(
            salvando
                ? 'SALVANDO CHAMADA...'
                : 'SALVAR CHAMADA',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: SifeTheme.primaryRed,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                SifeTheme.primaryRed,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

