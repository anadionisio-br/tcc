import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/face_test_config.dart';
import '../controllers/frequencia_controller.dart';
import 'totem_facial_page.dart';
import 'cadastro_rosto_page.dart';

class FrequenciaPage extends StatefulWidget {
  const FrequenciaPage({Key? key}) : super(key: key);

  @override
  State<FrequenciaPage> createState() => _FrequenciaPageState();
}

class _FrequenciaPageState extends State<FrequenciaPage> {
  final TextEditingController _pesquisaController =
      TextEditingController();

  String _pesquisa = '';

  final Set<int> _salvandoAlunos = {};

  bool _salvandoLote = false;

  @override
  void initState() {
    super.initState();

    _pesquisaController.addListener(() {
      if (!mounted) return;

      setState(() {
        _pesquisa =
            _pesquisaController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarChamada();
    });
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  // ============================================================
  // CARREGAR CHAMADA
  // ============================================================

  Future<void> _carregarChamada() async {
    if (!mounted) return;

    final controller =
        context.read<FrequenciaController>();

    if (controller.turmaSelecionada == null ||
        controller.turmaSelecionada! <= 0) {
      return;
    }

    await controller.buscarChamada();
  }

  // ============================================================
  // STATUS DO ALUNO
  // ============================================================

  bool _alunoEstaSalvando(int idAluno) {
    return _salvandoAlunos.contains(idAluno);
  }

  Future<void> _alterarStatusAluno(
  FrequenciaController controller,
  dynamic aluno,
  bool novoPresente,
) async {
  final int idAluno = aluno.idAluno;

  // Não permite clicar enquanto o lote está sendo salvo.
  if (_salvandoLote) {
    return;
  }

  // Evita dois cliques simultâneos no mesmo aluno.
  if (_salvandoAlunos.contains(idAluno)) {
    return;
  }

  // Verifica se existe turma selecionada.
  if (controller.turmaSelecionada == null ||
      controller.turmaSelecionada! <= 0) {
    _mostrarMensagem(
      'Nenhuma turma foi selecionada.',
      erro: true,
    );
    return;
  }

  // Não permite registrar frequência em data futura.
  if (_dataEhFutura(controller.dataSelecionada)) {
    _mostrarMensagem(
      'Não é permitido registrar chamada em uma data futura.',
      erro: true,
    );
    return;
  }

  final String novoStatus =
      novoPresente ? 'Presente' : 'Ausente';

  // Se já estiver no status desejado, não faz nada.
  if (aluno.status == novoStatus) {
    return;
  }

  // Guarda o status anterior para podermos restaurar
  // caso a API apresente algum erro.
  final String statusAnterior =
      aluno.status?.toString() ?? 'Ausente';

  // ============================================================
  // ALTERA VISUALMENTE ANTES DE ENVIAR
  // ============================================================

  aluno.status = novoStatus;

  setState(() {
    _salvandoAlunos.add(idAluno);
  });

  try {
    bool sucesso;

    // ============================================================
    // ENVIA PARA O BANCO
    // ============================================================

    if (novoStatus == 'Presente') {
      sucesso = await controller.registrarPresencaFacial(
        idAluno,
      );
    } else {
      sucesso = await controller.registrarAusencia(
        idAluno,
      );
    }

    if (!mounted) {
      return;
    }

    // ============================================================
    // SE DEU ERRO, RESTAURA O STATUS ANTERIOR
    // ============================================================

    if (!sucesso) {
      aluno.status = statusAnterior;

      _mostrarMensagem(
        'Não foi possível salvar a frequência.',
        erro: true,
      );

      setState(() {});
      return;
    }

    // ============================================================
    // SUCESSO
    // ============================================================

    _mostrarMensagem(
      '${aluno.nome} marcado como $novoStatus.',
      sucesso: true,
    );
  } catch (e, stackTrace) {
    debugPrint(
      'ERRO AO ALTERAR STATUS DO ALUNO: $e',
    );

    debugPrint(
      'STACK: $stackTrace',
    );

    if (!mounted) {
      return;
    }

    // Restaura o status anterior.
    aluno.status = statusAnterior;

    _mostrarMensagem(
      'Erro ao salvar a frequência.',
      erro: true,
    );

    setState(() {});
  } finally {
    if (mounted) {
      setState(() {
        _salvandoAlunos.remove(idAluno);
      });
    }
  }
}


  String _getIniciais(String nome) {
    if (nome.trim().isEmpty) {
      return '?';
    }

    final partes =
        nome.trim().split(RegExp(r'\s+'));

    if (partes.length == 1) {
      return partes[0]
          .substring(
            0,
            partes[0].length >= 2 ? 2 : 1,
          )
          .toUpperCase();
    }

    return (
      partes.first[0] +
      partes[1][0]
    ).toUpperCase();
  }

  // ============================================================
  // DATA FUTURA
  // ============================================================

  bool _dataEhFutura(DateTime data) {
    final hoje = DateTime.now();

    final hojeSemHora = DateTime(
      hoje.year,
      hoje.month,
      hoje.day,
    );

    final dataSemHora = DateTime(
      data.year,
      data.month,
      data.day,
    );

    return dataSemHora.isAfter(hojeSemHora);
  }

  // ============================================================
  // TURMA
  // ============================================================

  Map<String, dynamic>? _getTurmaSelecionada(
    FrequenciaController controller,
  ) {
    final idSelecionado =
        controller.turmaSelecionada;

    if (idSelecionado == null) {
      return null;
    }

    for (final turma in controller.turmas) {
      final idTurma = int.tryParse(
        turma['id_turma'].toString(),
      );

      if (idTurma == idSelecionado) {
        return turma;
      }
    }

    return null;
  }

  String _getNomeTurma(
    FrequenciaController controller,
  ) {
    final turma =
        _getTurmaSelecionada(controller);

    if (turma == null) {
      return 'Turma não selecionada';
    }

    final nome =
        turma['nome_turma']?.toString().trim() ?? '';

    final serie =
        turma['serie']?.toString().trim() ?? '';

    if (nome.isNotEmpty) {
      return nome;
    }

    if (serie.isNotEmpty) {
      return serie;
    }

    return 'Turma ${controller.turmaSelecionada}';
  }

  String _getDetalhesTurma(
    FrequenciaController controller,
  ) {
    final turma =
        _getTurmaSelecionada(controller);

    if (turma == null) {
      return 'Selecione uma turma para continuar';
    }

    final periodo =
        turma['periodo']?.toString().trim() ?? '';

    final sala =
        turma['sala']?.toString().trim().isNotEmpty == true
            ? turma['sala'].toString().trim()
            : turma['numero_sala']
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? turma['numero_sala']
                    .toString()
                    .trim()
                : turma['sala_turma']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true
                    ? turma['sala_turma']
                        .toString()
                        .trim()
                    : '';

    final informacoes = <String>[];

    if (periodo.isNotEmpty) {
      informacoes.add(periodo);
    }

    if (sala.isNotEmpty) {
      informacoes.add(
        sala.toLowerCase().startsWith('sala')
            ? sala
            : 'Sala $sala',
      );
    }

    if (informacoes.isEmpty) {
      return 'Turma selecionada';
    }

    return informacoes.join(' • ');
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _selecionarData(
    FrequenciaController controller,
  ) async {
    final agora = DateTime.now();

    final hoje = DateTime(
      agora.year,
      agora.month,
      agora.day,
    );

    DateTime dataInicial = DateTime(
      controller.dataSelecionada.year,
      controller.dataSelecionada.month,
      controller.dataSelecionada.day,
    );

    if (dataInicial.isAfter(hoje)) {
      dataInicial = hoje;
    }

    const anoInicial = 2025;

    final primeiraData =
        DateTime(anoInicial, 1, 1);

    if (dataInicial.isBefore(primeiraData)) {
      dataInicial = primeiraData;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: primeiraData,
      lastDate: hoje,
      helpText: 'Selecione a data da aula',
      cancelText: 'Cancelar',
      confirmText: 'Selecionar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary:
                  SifeTheme.primaryRed,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface:
                  Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    final dataEscolhida = DateTime(
      picked.year,
      picked.month,
      picked.day,
    );

    await controller.mudarData(
      dataEscolhida,
    );
  }

  // ============================================================
  // ATUALIZAR
  // ============================================================

  Future<void> _atualizar(
    FrequenciaController controller,
  ) async {
    if (_salvandoAlunos.isNotEmpty ||
        _salvandoLote) {
      return;
    }

    await controller.buscarChamada();

    if (!mounted) return;

    _mostrarMensagem(
      'Frequência atualizada.',
      sucesso: true,
    );
  }

  // ============================================================
  // SALVAR CHAMADA
  // ============================================================

  Future<void> _salvarChamadaLote(
    FrequenciaController controller,
  ) async {
    if (_salvandoLote) return;

    if (controller.turmaSelecionada == null ||
        controller.turmaSelecionada! <= 0) {
      _mostrarMensagem(
        'Nenhuma turma foi selecionada.',
        erro: true,
      );
      return;
    }

    if (controller.alunos.isEmpty) {
      _mostrarMensagem(
        'Não existem alunos para registrar a chamada.',
        erro: true,
      );
      return;
    }

    if (_dataEhFutura(
      controller.dataSelecionada,
    )) {
      _mostrarMensagem(
        'Não é permitido registrar chamada em uma data futura.',
        erro: true,
      );
      return;
    }

    final alunosParaSalvar =
        List<dynamic>.from(
      controller.alunos,
    );

    setState(() {
      _salvandoLote = true;

      for (final aluno in alunosParaSalvar) {
        _salvandoAlunos.add(
          aluno.idAluno,
        );
      }
    });

    final resultados =
        await Future.wait(
      alunosParaSalvar.map(
        (aluno) async {
          try {
            if (aluno.status == 'Presente') {
              return await controller
                  .registrarPresencaFacial(
                aluno.idAluno,
              );
            }

            return await controller
                .registrarAusencia(
              aluno.idAluno,
            );
          } catch (e) {
            debugPrint(
              'Erro ao salvar aluno '
              '${aluno.idAluno}: $e',
            );

            return false;
          }
        },
      ),
    );

    if (!mounted) return;

    int sucessos = 0;
    int erros = 0;

    for (final resultado in resultados) {
      if (resultado) {
        sucessos++;
      } else {
        erros++;
      }
    }

    setState(() {
      _salvandoLote = false;

      for (final aluno in alunosParaSalvar) {
        _salvandoAlunos.remove(
          aluno.idAluno,
        );
      }
    });

    if (erros == 0) {
      _mostrarMensagem(
        '$sucessos aluno(s) salvo(s) com sucesso!',
        sucesso: true,
      );
    } else {
      _mostrarMensagem(
        '$sucessos salvo(s) e $erros com erro.',
        aviso: true,
      );
    }
  }

  // ============================================================
  // TOTEM
  // ============================================================

  Future<void> _abrirTotem(
    FrequenciaController controller,
  ) async {
    if (controller.turmaSelecionada == null ||
        controller.turmaSelecionada! <= 0) {
      _mostrarMensagem(
        'Nenhuma turma foi selecionada.',
        erro: true,
      );
      return;
    }

    if (_dataEhFutura(
      controller.dataSelecionada,
    )) {
      _mostrarMensagem(
        'Não é permitido registrar chamada em uma data futura.',
        erro: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const TotemFacialPage(),
        settings: RouteSettings(
          arguments: {
            'id_turma':
                controller.turmaSelecionada,
          },
        ),
      ),
    );
  }

  // ============================================================
  // CADASTRAR ROSTO
  // ============================================================

  Future<void> _cadastrarRosto(
    FrequenciaController controller,
  ) async {
    final resultado =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const CadastroRostoPage(),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      _mostrarMensagem(
        'Rosto cadastrado com sucesso.',
        sucesso: true,
      );
    }
  }

  // ============================================================
  // TODOS PRESENTES
  // ============================================================

  Future<void> _marcarTodosPresentes(
  FrequenciaController controller,
) async {
  if (_salvandoLote) return;

  if (controller.alunos.isEmpty) {
    return;
  }

  if (_dataEhFutura(controller.dataSelecionada)) {
    _mostrarMensagem(
      'Não é permitido registrar chamada em uma data futura.',
      erro: true,
    );
    return;
  }

  int alterados = 0;

  for (final aluno in controller.alunos) {
    if (aluno.status != 'Presente') {
      aluno.status = 'Presente';
      alterados++;
    }
  }

  if (mounted) {
    setState(() {});
  }

  _mostrarMensagem(
    alterados == 0
        ? 'Todos os alunos já estão presentes.'
        : '$alterados aluno(s) marcado(s) como presente.',
    sucesso: alterados > 0,
    aviso: alterados == 0,
  );
}
  // ============================================================
  // TODOS AUSENTES
  // ============================================================

  Future<void> _marcarTodosAusentes(
  FrequenciaController controller,
) async {
  if (_salvandoLote) return;

  if (controller.alunos.isEmpty) {
    return;
  }

  if (_dataEhFutura(controller.dataSelecionada)) {
    _mostrarMensagem(
      'Não é permitido registrar chamada em uma data futura.',
      erro: true,
    );
    return;
  }

  int alterados = 0;

  for (final aluno in controller.alunos) {
    if (aluno.status != 'Ausente') {
      aluno.status = 'Ausente';
      alterados++;
    }
  }

  if (mounted) {
    setState(() {});
  }

  _mostrarMensagem(
    alterados == 0
        ? 'Todos os alunos já estão ausentes.'
        : '$alterados aluno(s) marcado(s) como ausente.',
    sucesso: alterados > 0,
    aviso: alterados == 0,
  );
}
  // ============================================================
  // VOLTAR
  // ============================================================

  void _voltarParaTurmas() {
    if (_salvandoAlunos.isNotEmpty ||
        _salvandoLote) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _mostrarMensagem(
    String mensagem, {
    bool sucesso = false,
    bool erro = false,
    bool aviso = false,
  }) {
    if (!mounted) return;

    Color cor =
        const Color(0xFF334155);

    if (sucesso) {
      cor = const Color(0xFF16A34A);
    } else if (erro) {
      cor = const Color(0xFFD92D20);
    } else if (aviso) {
      cor = const Color(0xFFF59E0B);
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration:
              const Duration(seconds: 2),
          backgroundColor: cor,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                sucesso
                    ? Icons.check_circle_outline
                    : erro
                        ? Icons.error_outline
                        : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensagem,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ============================================================
  // FILTRAR
  // ============================================================

  List<dynamic> _alunosFiltrados(
    FrequenciaController controller,
  ) {
    if (_pesquisa.isEmpty) {
      return controller.alunos;
    }

    return controller.alunos.where(
      (aluno) {
        final nome =
            aluno.nome.toLowerCase();

        final matricula =
            aluno.idAluno.toString();

        return nome.contains(_pesquisa) ||
            matricula.contains(_pesquisa);
      },
    ).toList();
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
        largura >= 600 &&
        largura < 1000;

    final dataFutura =
        _dataEhFutura(
      controller.dataSelecionada,
    );

    final podeRegistrar =
        controller.turmaSelecionada != null &&
        controller.turmaSelecionada! > 0 &&
        controller.alunos.isNotEmpty &&
        !dataFutura &&
        !controller.carregando &&
        !_salvandoLote;

    final alunosFiltrados =
        _alunosFiltrados(controller);

    final total =
        controller.alunos.length;

    final presentes =
        controller.alunos
            .where(
              (aluno) =>
                  aluno.status == 'Presente',
            )
            .length;

    final ausentes =
        total - presentes;

    final aproveitamento =
        total > 0
            ? (presentes / total) * 100
            : 0.0;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7F9),
      floatingActionButton:
          _buildTotemButton(controller),
      body: SafeArea(
        child: controller.carregando &&
                controller.alunos.isEmpty
            ? const Center(
                child:
                    CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                    SifeTheme.primaryRed,
                  ),
                ),
              )
            : RefreshIndicator(
                color:
                    SifeTheme.primaryRed,
                onRefresh: () =>
                    _atualizar(controller),
                child:
                    SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      EdgeInsets.fromLTRB(
                    celular
                        ? 14
                        : tablet
                            ? 24
                            : 32,
                    celular ? 16 : 24,
                    celular
                        ? 14
                        : tablet
                            ? 24
                            : 32,
                    celular ? 120 : 110,
                  ),
                  child: Center(
                    child:
                        ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 1500,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          _buildVoltar(),
                          const SizedBox(
                              height: 18),

                          _buildCabecalho(
                            largura: largura,
                            celular: celular,
                            tablet: tablet,
                            controller:
                                controller,
                            podeRegistrar:
                                podeRegistrar,
                          ),

                          const SizedBox(
                              height: 22),

                          _buildTurma(
                            controller,
                            celular,
                          ),

                          const SizedBox(
                              height: 20),

                          if (dataFutura)
                            _buildAvisoDataFutura(),

                          _buildControles(
                            controller,
                            dataFutura,
                            podeRegistrar,
                            celular,
                          ),

                          const SizedBox(
                              height: 20),

                          _buildEstatisticas(
                            total: total,
                            presentes:
                                presentes,
                            ausentes:
                                ausentes,
                            aproveitamento:
                                aproveitamento,
                            largura:
                                largura,
                          ),

                          const SizedBox(
                              height: 24),

                          _buildListaAlunos(
                            controller,
                            alunosFiltrados,
                            total,
                            podeRegistrar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // TOTEM
  // ============================================================

  Widget _buildTotemButton(
    FrequenciaController controller,
  ) {
    final dataFutura =
        _dataEhFutura(
      controller.dataSelecionada,
    );

    final podeRegistrar =
        controller.turmaSelecionada != null &&
        controller.turmaSelecionada! > 0 &&
        controller.alunos.isNotEmpty &&
        !dataFutura &&
        !_salvandoLote;

    return FloatingActionButton.extended(
      backgroundColor:
          podeRegistrar
              ? SifeTheme.primaryRed
              : Colors.grey.shade400,
      elevation: 4,
      icon: const FaIcon(
        FontAwesomeIcons.expand,
        color: Colors.white,
        size: 15,
      ),
      label: Text(
        _salvandoLote
            ? 'Salvando...'
            : 'Ativar Modo Totem',
        style:
            const TextStyle(
          color: Colors.white,
          fontWeight:
              FontWeight.bold,
        ),
      ),
      onPressed:
          podeRegistrar
              ? () => _abrirTotem(
                    controller,
                  )
              : null,
    );
  }

  // ============================================================
  // VOLTAR
  // ============================================================

  Widget _buildVoltar() {
    final bloqueado =
        _salvandoAlunos.isNotEmpty ||
            _salvandoLote;

    return InkWell(
      onTap: bloqueado
          ? null
          : _voltarParaTurmas,
      borderRadius:
          BorderRadius.circular(10),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 4,
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: bloqueado
                  ? Colors.grey
                  : SifeTheme.primaryRed,
            ),
            const SizedBox(width: 7),
            Text(
              'Voltar para Turmas',
              style: TextStyle(
                color: bloqueado
                    ? Colors.grey
                    : SifeTheme.primaryRed,
                fontSize: 15,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO
  // ============================================================

  Widget _buildCabecalho({
    required double largura,
    required bool celular,
    required bool tablet,
    required FrequenciaController controller,
    required bool podeRegistrar,
  }) {
    final botoes =
        _buildBotoesCabecalho(
      controller,
      podeRegistrar,
    );

    if (celular || tablet) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'REGISTRO DE AULA',
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Frequência',
            style: TextStyle(
              fontSize:
                  celular ? 28 : 30,
              fontWeight:
                  FontWeight.w900,
              color:
                  const Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Gerencie a presença dos alunos desta turma.',
            style: TextStyle(
              fontSize:
                  celular ? 13 : 14,
              color:
                  Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: botoes,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'REGISTRO DE AULA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF64748B),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Frequência',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Gerencie a presença dos alunos desta turma.',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Flexible(
          child: Align(
            alignment:
                Alignment.centerRight,
            child: botoes,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTÕES
  // ============================================================

  Widget _buildBotoesCabecalho(
    FrequenciaController controller,
    bool podeRegistrar,
  ) {
    return Wrap(
      alignment:
          WrapAlignment.end,
      crossAxisAlignment:
          WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          style:
              OutlinedButton.styleFrom(
            backgroundColor:
                Colors.white,
            foregroundColor:
                SifeTheme.primaryRed,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            side: BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),
          icon: const FaIcon(
            FontAwesomeIcons.userPlus,
            size: 14,
          ),
          label: const Text(
            'Cadastrar Rosto',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          onPressed:
              _salvandoLote
                  ? null
                  : () => _cadastrarRosto(
                        controller,
                      ),
        ),
        ElevatedButton.icon(
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                podeRegistrar
                    ? SifeTheme.primaryRed
                    : Colors.grey.shade400,
            foregroundColor:
                Colors.white,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
          ),
          icon:
              _salvandoLote
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child:
                          CircularProgressIndicator(
                        color:
                            Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const FaIcon(
                      FontAwesomeIcons
                          .floppyDisk,
                      size: 14,
                    ),
          label: Text(
            _salvandoLote
                ? 'SALVANDO...'
                : 'SALVAR CHAMADA',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          onPressed:
              podeRegistrar
                  ? () => _salvarChamadaLote(
                        controller,
                      )
                  : null,
        ),
        Material(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(11),
          child: InkWell(
            onTap:
                _salvandoLote ||
                        _salvandoAlunos
                            .isNotEmpty
                    ? null
                    : () =>
                        _atualizar(
                          controller,
                        ),
            borderRadius:
                BorderRadius.circular(11),
            child: Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
                border: Border.all(
                  color:
                      Colors.grey.shade300,
                ),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color:
                    _salvandoLote ||
                            _salvandoAlunos
                                .isNotEmpty
                        ? Colors.grey
                        : SifeTheme
                            .primaryRed,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TURMA
  // ============================================================

  Widget _buildTurma(
    FrequenciaController controller,
    bool celular,
  ) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.all(
        celular ? 16 : 20,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE8EBEF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width:
                celular ? 44 : 50,
            height:
                celular ? 44 : 50,
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFFEE2E2),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.school_rounded,
              color:
                  SifeTheme.primaryRed,
              size:
                  celular ? 21 : 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'TURMA SELECIONADA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getNomeTurma(
                    controller,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:
                        celular ? 16 : 18,
                    fontWeight:
                        FontWeight.w800,
                    color:
                        const Color(
                      0xFF172033,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _getDetalhesTurma(
                    controller,
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
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
  // AVISO
  // ============================================================

  Widget _buildAvisoDataFutura() {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFFF7ED),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              const Color(0xFFF59E0B),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color:
                Color(0xFFD97706),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'A data selecionada é futura. Não é possível registrar ou alterar a chamada.',
              style: TextStyle(
                color:
                    Color(0xFF9A3412),
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTROLES
  // ============================================================

  Widget _buildControles(
    FrequenciaController controller,
    bool dataFutura,
    bool podeRegistrar,
    bool celular,
  ) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.all(
        celular ? 14 : 20,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE8EBEF),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder:
                (context, constraints) {
              final pequeno =
                  constraints.maxWidth < 700;

              if (pequeno) {
                return Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    _buildDataButton(
                      controller,
                      dataFutura,
                    ),
                    const SizedBox(
                        height: 10),
                    _buildTodosPresentes(
                      controller,
                      podeRegistrar,
                      fullWidth: true,
                    ),
                    const SizedBox(
                        height: 10),
                    _buildTodosAusentes(
                      controller,
                      podeRegistrar,
                      fullWidth: true,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child:
                        _buildDataButton(
                      controller,
                      dataFutura,
                    ),
                  ),
                  const SizedBox(
                      width: 14),
                  _buildTodosPresentes(
                    controller,
                    podeRegistrar,
                  ),
                  const SizedBox(
                      width: 10),
                  _buildTodosAusentes(
                    controller,
                    podeRegistrar,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller:
                _pesquisaController,
            enabled:
                !_salvandoLote,
            decoration:
                InputDecoration(
              hintText:
                  'Pesquisar por nome ou matrícula...',
              prefixIcon:
                  const Icon(
                Icons.search_rounded,
              ),
              suffixIcon:
                  _pesquisa.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _pesquisaController
                                .clear();
                          },
                          icon:
                              const Icon(
                            Icons.close_rounded,
                          ),
                        )
                      : null,
              filled: true,
              fillColor:
                  const Color(
                0xFFF8FAFC,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
                borderSide:
                    BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA BUTTON
  // ============================================================

  Widget _buildDataButton(
    FrequenciaController controller,
    bool dataFutura,
  ) {
    return InkWell(
      onTap:
          _salvandoLote
              ? null
              : () => _selecionarData(
                    controller,
                  ),
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(14),
        decoration:
            BoxDecoration(
          color:
              const Color(0xFFF8FAFC),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: dataFutura
                ? const Color(
                    0xFFF59E0B)
                : const Color(
                    0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color: dataFutura
                    ? const Color(
                        0xFFFFEDD5)
                    : const Color(
                        0xFFFEE2E2),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Icon(
                Icons
                    .calendar_month_rounded,
                color: dataFutura
                    ? const Color(
                        0xFFD97706)
                    : SifeTheme
                        .primaryRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'DATA DA AULA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(
                      height: 4),
                  Text(
                    controller
                        .dataFormatada,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF172033),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons
                  .keyboard_arrow_down_rounded,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TODOS PRESENTES
  // ============================================================

  Widget _buildTodosPresentes(
    FrequenciaController controller,
    bool podeRegistrar, {
    bool fullWidth = false,
  }) {
    return SizedBox(
      width:
          fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed:
            podeRegistrar &&
                    !_salvandoLote
                ? () =>
                    _marcarTodosPresentes(
                      controller,
                    )
                : null,
        icon: const Icon(
          Icons.check_circle_outline,
          size: 17,
          color:
              Color(0xFF16A34A),
        ),
        label: const Text(
          'Todos presentes',
          style: TextStyle(
            color:
                Color(0xFF15803D),
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TODOS AUSENTES
  // ============================================================

  Widget _buildTodosAusentes(
    FrequenciaController controller,
    bool podeRegistrar, {
    bool fullWidth = false,
  }) {
    return SizedBox(
      width:
          fullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed:
            podeRegistrar &&
                    !_salvandoLote
                ? () =>
                    _marcarTodosAusentes(
                      controller,
                    )
                : null,
        icon: const Icon(
          Icons.cancel_outlined,
          size: 17,
          color:
              Color(0xFFDC2626),
        ),
        label: const Text(
          'Todos ausentes',
          style: TextStyle(
            color:
                Color(0xFFB91C1C),
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ESTATÍSTICAS
  // ============================================================

  Widget _buildEstatisticas({
    required int total,
    required int presentes,
    required int ausentes,
    required double aproveitamento,
    required double largura,
  }) {
    final celular =
        largura < 600;

    final cards = [
      _buildStatCard(
        title: 'TOTAL',
        value: total.toString(),
        icon:
            Icons.groups_rounded,
        valueColor:
            const Color(0xFF1E293B),
      ),
      _buildStatCard(
        title: 'PRESENTES',
        value:
            presentes.toString(),
        icon:
            Icons.check_circle_rounded,
        valueColor:
            const Color(0xFF16A34A),
      ),
      _buildStatCard(
        title: 'AUSENTES',
        value:
            ausentes.toString(),
        icon:
            Icons.cancel_rounded,
        valueColor:
            const Color(0xFFD92D20),
      ),
      _buildStatCard(
        title: 'APROVEITAMENTO',
        value:
            '${aproveitamento.toStringAsFixed(0)}%',
        icon:
            Icons.analytics_rounded,
        valueColor:
            const Color(0xFF2563EB),
        progress:
            aproveitamento / 100,
      ),
    ];

    if (celular) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics:
            const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.45,
        children: cards,
      );
    }

    return Row(
      children:
          cards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      right: 7,
                      left: 7,
                    ),
                    child: card,
                  ),
                ),
              )
              .toList(),
    );
  }

  // ============================================================
  // LISTA
  // ============================================================

  Widget _buildListaAlunos(
    FrequenciaController controller,
    List<dynamic> alunosFiltrados,
    int total,
    bool podeRegistrar,
  ) {
    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE8EBEF),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              18,
              16,
              14,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ALUNOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF475569),
                    ),
                  ),
                ),
                Text(
                  _pesquisa.isNotEmpty
                      ? '${alunosFiltrados.length} encontrado(s)'
                      : '$total aluno(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
          ),
          if (alunosFiltrados.isEmpty)
            _buildListaVazia()
          else
            ListView.separated(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              itemCount:
                  alunosFiltrados.length,
              separatorBuilder:
                  (context, index) =>
                      const Divider(
                height: 1,
              ),
              itemBuilder:
                  (context, index) {
                final aluno =
                    alunosFiltrados[index];

                final isPresente =
                    aluno.status ==
                        'Presente';

                return _buildAlunoRow(
                  controller,
                  aluno,
                  isPresente,
                  podeRegistrar,
                );
              },
            ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTA VAZIA
  // ============================================================

  Widget _buildListaVazia() {
    return Padding(
      padding:
          const EdgeInsets.all(45),
      child: Column(
        children: [
          Icon(
            _pesquisa.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.groups_outlined,
            size: 45,
            color:
                Colors.grey.shade400,
          ),
          const SizedBox(height: 15),
          Text(
            _pesquisa.isNotEmpty
                ? 'Nenhum aluno encontrado'
                : 'Nenhum aluno cadastrado',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ALUNO
  // ============================================================

  Widget _buildAlunoRow(
    FrequenciaController controller,
    dynamic aluno,
    bool isPresente,
    bool podeRegistrar,
  ) {
    final idAluno =
        aluno.idAluno;

    final salvando =
        _salvandoAlunos.contains(
      idAluno,
    );

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildAvatarAluno(
                  aluno,
                  isPresente,
                  42,
                ),
                const SizedBox(
                    width: 14),
                Expanded(
                  child:
                      _buildInfoAluno(
                    aluno,
                  ),
                ),
              ],
            ),
          ),
          if (salvando)
            const Padding(
              padding:
                  EdgeInsets.only(
                right: 10,
              ),
              child:
                  SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      SifeTheme
                          .primaryRed,
                ),
              ),
            ),
          SizedBox(
            width: 190,
            child: Row(
              children: [
                Expanded(
                  child:
                      _buildStatusButton(
                    label: 'Presente',
                    ativo:
                        isPresente,
                    verde: true,
                    habilitado:
                        podeRegistrar &&
                            !salvando,
                    onTap: () =>
                        _alterarStatusAluno(
                      controller,
                      aluno,
                      true,
                    ),
                  ),
                ),
                const SizedBox(
                    width: 8),
                Expanded(
                  child:
                      _buildStatusButton(
                    label: 'Ausente',
                    ativo:
                        !isPresente,
                    verde: false,
                    habilitado:
                        podeRegistrar &&
                            !salvando,
                    onTap: () =>
                        _alterarStatusAluno(
                      controller,
                      aluno,
                      false,
                    ),
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
  // AVATAR
  // ============================================================

  Widget _buildAvatarAluno(
    dynamic aluno,
    bool isPresente,
    double tamanho,
  ) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration:
          BoxDecoration(
        color: isPresente
            ? const Color(
                0xFFDCFCE7)
            : const Color(
                0xFFF1F5F9),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Center(
        child: Text(
          _getIniciais(
            aluno.nome,
          ),
          style:
              TextStyle(
            color: isPresente
                ? const Color(
                    0xFF15803D)
                : const Color(
                    0xFF475569),
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFORMAÇÕES
  // ============================================================

  Widget _buildInfoAluno(
    dynamic aluno,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          aluno.nome,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
            fontSize: 14,
            color:
                Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Matrícula: ${aluno.idAluno}',
          style: TextStyle(
            color:
                Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          aluno.temRosto ? 'Rosto cadastrado' :
              (FaceTestConfig.ativo && aluno.temRostoTeste ? 'Foto de teste cadastrada' : 'Rosto pendente'),
          style: TextStyle(
            fontSize: 11,
            color: aluno.temRosto ? const Color(0xFF15803D) : const Color(0xFFB45309),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTÃO STATUS
  // ============================================================

  Widget _buildStatusButton({
    required String label,
    required bool ativo,
    required bool verde,
    required bool habilitado,
    required VoidCallback onTap,
  }) {
    final cor = verde
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    final fundo = verde
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFEF2F2);

    return InkWell(
      onTap:
          habilitado ? onTap : null,
      borderRadius:
          BorderRadius.circular(9),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 150,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 8,
        ),
        decoration:
            BoxDecoration(
          color: !habilitado
              ? const Color(
                  0xFFF1F5F9)
              : ativo
                  ? fundo
                  : Colors.white,
          borderRadius:
              BorderRadius.circular(9),
          border:
              Border.all(
            color: !habilitado
                ? const Color(
                    0xFFE2E8F0)
                : ativo
                    ? cor
                    : const Color(
                        0xFFE2E8F0),
            width:
                ativo ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              verde
                  ? Icons
                      .check_circle_outline
                  : Icons
                      .cancel_outlined,
              size: 15,
              color: !habilitado
                  ? Colors.grey.shade400
                  : ativo
                      ? cor
                      : Colors.grey.shade400,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.bold,
                  color: !habilitado
                      ? Colors.grey.shade400
                      : ativo
                          ? cor
                          : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD ESTATÍSTICA
  // ============================================================

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color valueColor,
    double? progress,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color:
              const Color(0xFFE8EBEF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  valueColor.withOpacity(.09),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: valueColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Colors.grey.shade500,
                  ),
                ),
                const SizedBox(
                    height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                        FontWeight.w900,
                    color: valueColor,
                  ),
                ),
                if (progress != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 6,
                    ),
                    child:
                        LinearProgressIndicator(
                      value: progress.clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}