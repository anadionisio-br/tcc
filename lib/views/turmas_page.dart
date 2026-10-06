import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';
import 'navigation_menu.dart';

class TurmasPage extends StatefulWidget {
  const TurmasPage({Key? key}) : super(key: key);

  @override
  State<TurmasPage> createState() => _TurmasPageState();
}

class _TurmasPageState extends State<TurmasPage> {
  int? _turmaSelecionadaId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<FrequenciaController>()
          .buscarTurmasDoBanco();
    });
  }

  // ============================================================
  // SELECIONAR TURMA
  // ============================================================

  void _confirmarEAvancar(
    Map<String, dynamic> turma,
  ) {
    final idTurma =
        turma['id_turma'] ?? turma['id'];

    setState(() {
      _turmaSelecionadaId = idTurma;
    });

    context
        .read<FrequenciaController>()
        .mudarTurma(idTurma);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const NavigationMenu(),
      ),
    );
  }

  // ============================================================
  // DETALHES
  // ============================================================

  String _getDetalhesTurma(
    Map<String, dynamic> turma,
  ) {
    final turno =
        turma['turno']?.toString().trim() ?? '';

    final periodo =
        turma['periodo']?.toString().trim() ?? '';

    final sala =
        turma['sala']?.toString().trim() ?? '';

    final informacoes = <String>[];

    final horario =
        turno.isNotEmpty
            ? turno
            : periodo;

    if (horario.isNotEmpty) {
      informacoes.add(horario);
    }

    if (sala.isNotEmpty) {
      informacoes.add(
        sala.toLowerCase().startsWith('sala')
            ? sala
            : 'Sala $sala',
      );
    }

    if (informacoes.isEmpty) {
      return 'Informações da turma';
    }

    return informacoes.join('  •  ');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final controller =
        context.watch<FrequenciaController>();

    final largura =
        MediaQuery.of(context).size.width;

    final celular = largura < 600;
    final tablet =
        largura >= 600 && largura < 1000;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9),

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(
              celular: celular,
              tablet: tablet,
              total: controller.turmas.length,
            ),

            Expanded(
              child: _buildConteudo(
                controller,
                celular,
                tablet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader({
    required bool celular,
    required bool tablet,
    required int total,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE8EBEF),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              celular
                  ? 18
                  : tablet
                      ? 28
                      : 42,
          vertical:
              celular ? 18 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1400,
            ),
            child: Row(
              children: [
                // ÍCONE
                Container(
                  width:
                      celular ? 46 : 54,
                  height:
                      celular ? 46 : 54,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xFFFEE2E2),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color:
                        SifeTheme.primaryRed,
                    size:
                        celular ? 22 : 26,
                  ),
                ),

                const SizedBox(width: 14),

                // TÍTULOS
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GESTÃO ESCOLAR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: 1.2,
                          color:
                              Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Minhas Turmas',
                        style: TextStyle(
                          fontSize:
                              celular ? 21 : 25,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              const Color(
                            0xFF172033,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // CONTADOR
                if (!celular)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFF8FAFC,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      border: Border.all(
                        color:
                            const Color(
                          0xFFE2E8F0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 17,
                          color:
                              Color(0xFF64748B),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '$total ${total == 1 ? 'turma' : 'turmas'}',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONTEÚDO
  // ============================================================

  Widget _buildConteudo(
    FrequenciaController controller,
    bool celular,
    bool tablet,
  ) {
    return RefreshIndicator(
      color: SifeTheme.primaryRed,
      onRefresh: () async {
        await controller.buscarTurmasDoBanco();
      },
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          celular
              ? 16
              : tablet
                  ? 28
                  : 42,
          celular ? 22 : 30,
          celular
              ? 16
              : tablet
                  ? 28
                  : 42,
          30,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1400,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildIntro(
                  controller,
                  celular,
                ),

                const SizedBox(height: 24),

                if (controller.carregandoTurmas)
                  _buildCarregando()
                else if (controller.turmas.isEmpty)
                  _buildSemTurmas()
                else
                  _buildLista(
                    controller,
                    celular,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INTRODUÇÃO
  // ============================================================

  Widget _buildIntro(
    FrequenciaController controller,
    bool celular,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Selecione uma turma',
          style: TextStyle(
            fontSize:
                celular ? 25 : 29,
            fontWeight:
                FontWeight.w800,
            color:
                const Color(0xFF172033),
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'Escolha a turma que deseja gerenciar nesta sessão.',
          style: TextStyle(
            fontSize:
                celular ? 13 : 14,
            color:
                const Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(15),
          decoration:
              BoxDecoration(
            color:
                const Color(0xFFFFF7F7),
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color:
                  const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  color:
                      SifeTheme.primaryRed,
                  size: 19,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Text(
                  'Selecione uma turma para acessar a frequência e os recursos da classe.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color:
                        Colors.grey.shade700,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARREGANDO
  // ============================================================

  Widget _buildCarregando() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 80,
      ),
      decoration:
          _boxDecoration(),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            padding:
                const EdgeInsets.all(17),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFFEE2E2),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child:
                const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                SifeTheme.primaryRed,
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Carregando suas turmas...',
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
              color:
                  Color(0xFF334155),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Aguarde enquanto buscamos os dados.',
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEM TURMAS
  // ============================================================

  Widget _buildSemTurmas() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 65,
      ),
      decoration:
          _boxDecoration(),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF1F5F9),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.school_outlined,
              size: 34,
              color:
                  Colors.grey.shade400,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Nenhuma turma encontrada',
            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(0xFF334155),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Não encontramos turmas cadastradas para sua conta.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:
                  Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTA
  // ============================================================

  Widget _buildLista(
    FrequenciaController controller,
    bool celular,
  ) {
    return Column(
      children: [
        ...controller.turmas.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final turma = entry.value;

            return Padding(
              padding:
                  EdgeInsets.only(
                bottom:
                    index ==
                            controller
                                    .turmas
                                    .length -
                                1
                        ? 0
                        : 12,
              ),
              child:
                  _buildTurmaCard(
                turma,
                celular,
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // CARD DA TURMA
  // ============================================================

  Widget _buildTurmaCard(
    Map<String, dynamic> turma,
    bool celular,
  ) {
    final idTurma =
        turma['id_turma'] ?? turma['id'];

    final isSelected =
        _turmaSelecionadaId == idTurma;

    final nomeTurma =
        (
          turma['nome_turma'] ??
          turma['nome'] ??
          'Sem nome'
        ).toString();

    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(17),
      child: InkWell(
        onTap: () =>
            _confirmarEAvancar(turma),
        borderRadius:
            BorderRadius.circular(17),
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),
          padding:
              EdgeInsets.all(
            celular ? 15 : 18,
          ),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(17),
            border: Border.all(
              color: isSelected
                  ? SifeTheme.primaryRed
                  : const Color(
                      0xFFE5E7EB,
                    ),
              width:
                  isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(
                  isSelected
                      ? 0.07
                      : 0.035,
                ),
                blurRadius:
                    isSelected ? 16 : 10,
                offset:
                    const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ÍCONE
              Container(
                width:
                    celular ? 50 : 56,
                height:
                    celular ? 50 : 56,
                decoration:
                    BoxDecoration(
                  color: isSelected
                      ? SifeTheme
                          .primaryRed
                      : const Color(
                          0xFFFEE2E2,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size:
                      celular ? 23 : 26,
                  color: isSelected
                      ? Colors.white
                      : SifeTheme
                          .primaryRed,
                ),
              ),

              const SizedBox(width: 15),

              // INFORMAÇÕES
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeTurma,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize:
                            celular ? 15 : 16,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            const Color(
                          0xFF172033,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        Icon(
                          Icons
                              .schedule_rounded,
                          size: 14,
                          color:
                              Colors.grey.shade500,
                        ),
                        const SizedBox(
                            width: 5),
                        Expanded(
                          child: Text(
                            _getDetalhesTurma(
                              turma,
                            ),
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // SETA
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: isSelected
                      ? const Color(
                          0xFFFEE2E2,
                        )
                      : const Color(
                          0xFFF8FAFC,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 14,
                  color: isSelected
                      ? SifeTheme
                          .primaryRed
                      : const Color(
                          0xFF94A3B8,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DECORAÇÃO
  // ============================================================

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(18),
      border: Border.all(
        color:
            const Color(0xFFE8EBEF),
      ),
      boxShadow: [
        BoxShadow(
          color:
              Colors.black.withOpacity(
            0.025,
          ),
          blurRadius: 12,
          offset:
              const Offset(0, 4),
        ),
      ],
    );
  }
}
