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

    // Busca as turmas diretamente do banco
    // ao carregar a tela.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<FrequenciaController>()
          .buscarTurmasDoBanco();
    });
  }

  // ============================================================
  // SELECIONAR TURMA E AVANÇAR
  // ============================================================

  void _confirmarEAvancar(
    Map<String, dynamic> turma,
  ) {
    final idTurma =
        turma['id_turma'] ?? turma['id'];

    setState(() {
      _turmaSelecionadaId = idTurma;
    });

    // Define a turma escolhida no controller.
    context
        .read<FrequenciaController>()
        .mudarTurma(idTurma);

    // Abre o menu principal.
    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const NavigationMenu(),
  ),
);
  }

  // ============================================================
  // INFORMAÇÕES DA TURMA
  // ============================================================

  String _getDetalhesTurma(
    Map<String, dynamic> turma,
  ) {
    final turno =
        turma['turno']?.toString().trim() ?? '';

    final sala =
        turma['sala']?.toString().trim() ?? '';

    final informacoes = <String>[];

    if (turno.isNotEmpty) {
      informacoes.add(turno);
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

    return informacoes.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final controller =
        context.watch<FrequenciaController>();

    return Scaffold(
      backgroundColor:
          SifeTheme.bgLight,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        title: const Text(
          'Minhas Turmas',
          style: TextStyle(
            color: SifeTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ========================================================
      // CONTEÚDO
      // ========================================================

      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(20.0),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Text(
                'Selecione uma turma',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      SifeTheme.textDark,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                'Escolha a turma que deseja gerenciar nesta sessão:',
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // LISTA DE TURMAS
              // ==================================================

              Expanded(
                child:
                    controller.carregandoTurmas

                        // CARREGANDO
                        ? const Center(
                            child:
                                CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                SifeTheme
                                    .primaryRed,
                              ),
                            ),
                          )

                        // NENHUMA TURMA
                        : controller
                                .turmas
                                .isEmpty
                            ? Center(
                                child:
                                    Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,

                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons
                                          .folderOpen,
                                      size: 40,
                                      color: Colors
                                          .grey
                                          .shade400,
                                    ),

                                    const SizedBox(
                                      height: 12,
                                    ),

                                    Text(
                                      'Nenhuma turma encontrada no banco.',
                                      style:
                                          TextStyle(
                                        color: Colors
                                            .grey
                                            .shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )

                            // LISTA
                            : ListView.builder(
                                itemCount:
                                    controller
                                        .turmas
                                        .length,

                                itemBuilder:
                                    (
                                  context,
                                  index,
                                ) {
                                  final turma =
                                      controller
                                          .turmas[index];

                                  final idTurma =
                                      turma[
                                              'id_turma'] ??
                                          turma[
                                              'id'];

                                  final isSelected =
                                      _turmaSelecionadaId ==
                                          idTurma;

                                  final nomeTurma =
                                      (
                                    turma[
                                            'nome_turma'] ??
                                        turma[
                                            'nome'] ??
                                        'Sem nome'
                                  ).toString();

                                  return Card(
                                    margin:
                                        const EdgeInsets
                                            .only(
                                      bottom: 12,
                                    ),

                                    elevation: 0,

                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        16,
                                      ),
                                      side:
                                          BorderSide(
                                        color:
                                            isSelected
                                                ? SifeTheme
                                                    .primaryRed
                                                : SifeTheme
                                                    .borderColor,
                                        width:
                                            isSelected
                                                ? 2
                                                : 1,
                                      ),
                                    ),

                                    child:
                                        ListTile(
                                      contentPadding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal:
                                            16,
                                        vertical: 8,
                                      ),

                                      // ÍCONE
                                      leading:
                                          Container(
                                        padding:
                                            const EdgeInsets
                                                .all(
                                          12,
                                        ),

                                        decoration:
                                            BoxDecoration(
                                          color:
                                              isSelected
                                                  ? SifeTheme
                                                      .primaryRed
                                                  : SifeTheme
                                                      .primaryRedSoft,
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            12,
                                          ),
                                        ),

                                        child:
                                            FaIcon(
                                          FontAwesomeIcons
                                              .users,
                                          size:
                                              20,
                                          color:
                                              isSelected
                                                  ? Colors
                                                      .white
                                                  : SifeTheme
                                                      .primaryRed,
                                        ),
                                      ),

                                      // NOME
                                      title:
                                          Text(
                                        nomeTurma,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                          fontSize:
                                              16,
                                          color:
                                              SifeTheme
                                                  .textDark,
                                        ),
                                      ),

                                      // TURNO E SALA
                                      subtitle:
                                          Text(
                                        _getDetalhesTurma(
                                          turma,
                                        ),
                                        style:
                                            TextStyle(
                                          fontSize:
                                              12,
                                          color:
                                              Colors
                                                  .grey
                                                  .shade600,
                                        ),
                                      ),

                                      // SETA
                                      trailing:
                                          const FaIcon(
                                        FontAwesomeIcons
                                            .chevronRight,
                                        size:
                                            14,
                                        color:
                                            Colors
                                                .grey,
                                      ),

                                      // SELECIONAR
                                      onTap:
                                          () =>
                                              _confirmarEAvancar(
                                        turma,
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}