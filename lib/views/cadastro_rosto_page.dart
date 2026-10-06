import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../config/face_test_config.dart';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/face_recognition_service.dart';
import '../controllers/frequencia_controller.dart';

class CadastroRostoPage extends StatefulWidget {
  const CadastroRostoPage({super.key});

  @override
  State<CadastroRostoPage> createState() => _CadastroRostoPageState();
}

class _CadastroRostoPageState extends State<CadastroRostoPage> {
  CameraController? _cameraController;

  bool _cameraInicializada = false;
  bool _inicializandoCamera = false;
  bool _rostoDetectado = false;
  bool _salvando = false;
  bool _carregandoAlunos = false;

  XFile? _fotoCapturada;
  Uint8List? _fotoBytes;

  Map<String, dynamic>? _alunoSelecionado;

  final TextEditingController _buscaController = TextEditingController();

  final ApiService _apiService = ApiService();

  final FaceRecognitionService _faceRecognitionService =
    FaceRecognitionService();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableClassification: true,
    ),
  );

  // Paleta de apoio para esta tela (mantém a cor primária do app).
  static const Color _bgTop = Color(0xFF11151C);
  static const Color _bgBottom = Color(0xFF1B212B);
  static const Color _cardBg = Color(0xFF232A36);
  static const Color _cardBorder = Color(0xFF313A48);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _success = Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarTela();
    });
  }

  // ============================================================
  // CARREGAR ALUNOS
  // ============================================================

  Future<void> _inicializarTela() async {
    // A câmera começa imediatamente.
    if (!kIsWeb) await _inicializarCamera();

    // Os alunos carregam separadamente.
    if (mounted) {
      await _carregarAlunos();
    }
  }

  Future<void> _carregarAlunos() async {
    if (!mounted) return;

    setState(() {
      _carregandoAlunos = true;
    });

    try {
      final controller = context.read<FrequenciaController>();

      debugPrint('========================================');
      debugPrint('CADASTRO DE ROSTO');
      debugPrint('TURMA ATUAL: ${controller.turmaSelecionada}');
      debugPrint('ALUNOS ATUAIS: ${controller.alunos.length}');
      debugPrint('========================================');

      // Se não existe turma selecionada,
      // primeiro busca as turmas.
      if (controller.turmaSelecionada == null ||
          controller.turmaSelecionada! <= 0) {
        debugPrint('Nenhuma turma selecionada.');
        debugPrint('Buscando turmas...');

        await controller.buscarTurmasDoBanco();
      }

      // Depois que a turma estiver definida,
      // buscamos os alunos.
      if (controller.turmaSelecionada != null &&
          controller.turmaSelecionada! > 0) {
        debugPrint('Buscando alunos da turma ${controller.turmaSelecionada}');

        await controller.buscarChamada();

        debugPrint('ALUNOS APÓS BUSCA: ${controller.alunos.length}');
      }
    } catch (e, stackTrace) {
      debugPrint('ERRO AO CARREGAR ALUNOS: $e');
      debugPrint('$stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _carregandoAlunos = false;
        });
      }
    }
  }

  // ============================================================
  // INICIALIZAR CÂMERA
  // ============================================================

  Future<void> _inicializarCamera() async {
    if (_inicializandoCamera || _cameraInicializada) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _inicializandoCamera = true;
    });

    try {
      debugPrint('========================================');
      debugPrint('INICIANDO CÂMERA');
      debugPrint('========================================');

      // ============================================================
      // 1. VERIFICAR PERMISSÃO
      // ============================================================

      PermissionStatus status = await Permission.camera.status;

      debugPrint('PERMISSÃO ATUAL DA CÂMERA: $status');

      if (!status.isGranted) {
        status = await Permission.camera.request();

        debugPrint('PERMISSÃO APÓS SOLICITAÇÃO: $status');
      }

      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          throw Exception(
            'A permissão da câmera foi bloqueada. '
            'Abra as configurações do aplicativo e permita o acesso à câmera.',
          );
        }

        throw Exception('Permissão da câmera não concedida.');
      }

      // ============================================================
      // 2. BUSCAR CÂMERAS
      // ============================================================

      final cameras = await availableCameras();

      debugPrint('CÂMERAS ENCONTRADAS: ${cameras.length}');

      if (cameras.isEmpty) {
        throw Exception('Nenhuma câmera foi encontrada neste dispositivo.');
      }

      // ============================================================
      // 3. ESCOLHER CÂMERA FRONTAL
      // ============================================================

      CameraDescription cameraSelecionada;

      final camerasFrontais = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );

      if (camerasFrontais.isNotEmpty) {
        cameraSelecionada = camerasFrontais.first;
      } else {
        cameraSelecionada = cameras.first;
      }

      debugPrint('CÂMERA ESCOLHIDA: ${cameraSelecionada.name}');

      debugPrint('DIREÇÃO: ${cameraSelecionada.lensDirection}');

      // ============================================================
      // 4. CRIAR CONTROLLER
      // ============================================================

      final controller = CameraController(
        cameraSelecionada,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;

      // ============================================================
      // 5. INICIALIZAR
      // ============================================================

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      if (!controller.value.isInitialized) {
        throw Exception('A câmera foi criada, mas não foi inicializada.');
      }

      debugPrint('========================================');
      debugPrint('CÂMERA INICIALIZADA COM SUCESSO');
      debugPrint(
        'RESOLUÇÃO: '
        '${controller.value.previewSize?.width} x '
        '${controller.value.previewSize?.height}',
      );
      debugPrint('========================================');

      setState(() {
        _cameraInicializada = true;
      });
    } on CameraException catch (e) {
      debugPrint('========================================');
      debugPrint('CAMERA EXCEPTION');
      debugPrint('CÓDIGO: ${e.code}');
      debugPrint('DESCRIÇÃO: ${e.description}');
      debugPrint('========================================');

      if (mounted) {
        _exibirSnackBar(
          'Erro da câmera: ${e.description ?? e.code}',
          isErro: true,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('ERRO AO ABRIR CÂMERA');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('========================================');

      if (mounted) {
        _exibirSnackBar(
          e.toString().replaceFirst('Exception: ', ''),
          isErro: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _inicializandoCamera = false;
        });
      }
    }
  }

  // ============================================================
  // CAPTURAR FOTO
  // ============================================================

  Future<void> _capturarEVerificarRosto() async {
    if (FaceTestConfig.ativo) {
      try {
        final bytes = (await rootBundle.load(FaceTestConfig.foto)).buffer.asUint8List();
        if (!mounted || _alunoSelecionado == null) return;
        setState(() {
          _fotoBytes = bytes;
          _fotoCapturada = XFile.fromData(bytes, name: 'rosto-teste.png', mimeType: 'image/png');
          _rostoDetectado = true;
        });
      } catch (_) {
        _exibirSnackBar('Não foi possível carregar a foto de teste.', isErro: true);
      }
      return;
    }
    if (_alunoSelecionado == null) {
      _exibirSnackBar('Primeiro selecione um aluno.', isErro: true);
      return;
    }

    if (_cameraController == null ||
        !_cameraInicializada ||
        !_cameraController!.value.isInitialized) {
      _exibirSnackBar('A câmera ainda não está pronta.', isErro: true);
      return;
    }

    try {
      final XFile foto = await _cameraController!.takePicture();

      debugPrint('FOTO CAPTURADA: ${foto.path}');

      final inputImage = InputImage.fromFilePath(foto.path);

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      debugPrint('ROSTOS DETECTADOS: ${faces.length}');

      if (faces.isEmpty) {
        _exibirSnackBar(
          'Nenhum rosto foi detectado. Olhe diretamente para a câmera.',
          isErro: true,
        );
        return;
      }

      if (faces.length > 1) {
        _exibirSnackBar(
          'Foram detectados vários rostos. Apenas uma pessoa deve aparecer.',
          isErro: true,
        );
        return;
      }

      final bytes = await foto.readAsBytes();
      if (!mounted) return;

      setState(() {
        _fotoBytes = bytes;
        _fotoCapturada = foto;
        _rostoDetectado = true;
      });

      _exibirSnackBar('Rosto detectado com sucesso!');
    } catch (e) {
      debugPrint('ERRO AO CAPTURAR ROSTO: $e');

      if (mounted) {
        _exibirSnackBar('Erro ao capturar o rosto.', isErro: true);
      }
    }
  }

  // ============================================================
  // SALVAR CADASTRO
  // ============================================================

  Future<void> _salvarCadastro() async {
  if (_alunoSelecionado == null) {
    _exibirSnackBar(
      'Selecione um aluno primeiro.',
      isErro: true,
    );
    return;
  }

  if (_fotoCapturada == null) {
    _exibirSnackBar(
      'Capture o rosto do aluno primeiro.',
      isErro: true,
    );
    return;
  }

  if (_salvando) {
    return;
  }

  setState(() {
    _salvando = true;
  });

  try {
    final nomeAluno =
        (_alunoSelecionado!['nome'] ??
                _alunoSelecionado!['nome_aluno'] ??
                'Aluno')
            .toString();

    final idAluno = int.tryParse(
          (_alunoSelecionado!['id_aluno'] ??
                  _alunoSelecionado!['id'] ??
                  '')
              .toString(),
        ) ??
        0;

    if (idAluno <= 0) {
      _exibirSnackBar(
        'Aluno inválido.',
        isErro: true,
      );
      return;
    }

    debugPrint('========================================');
    debugPrint('SALVANDO BIOMETRIA FACIAL');
    debugPrint('ID ALUNO: $idAluno');
    debugPrint('NOME: $nomeAluno');
    debugPrint('FOTO: ${_fotoCapturada!.path}');
    debugPrint('========================================');

    // ============================================================
    // 1. LER A FOTO
    // ============================================================

    final imageBytes =
        await _fotoCapturada!.readAsBytes();

    if (imageBytes.isEmpty) {
      throw Exception(
        'A foto capturada está vazia.',
      );
    }

    if (FaceTestConfig.ativo) {
      await _apiService.enviarFotoTeste(bytes: imageBytes, idAluno: idAluno);
    } else {
      final embedding = await _faceRecognitionService.extrairRosto(imageBytes);
      if (embedding == null || embedding.isEmpty) {
        throw Exception('Não foi possível gerar a biometria. Tire outra foto de frente.');
      }
      final salvo = await _apiService.cadastrarRosto(
        idAluno: idAluno, embedding: embedding, caminhoFoto: _fotoCapturada!.path,
      );
      if (!salvo) throw Exception('Não foi possível salvar o rosto.');
    }
    if (!mounted) return;
    await context.read<FrequenciaController>().buscarChamada();

    // ============================================================
    // 5. FINALIZAR
    // ============================================================

    if (!mounted) return;

    _exibirSnackBar(
      FaceTestConfig.ativo ? 'Foto de teste associada a $nomeAluno.' : 'Rosto de $nomeAluno cadastrado com sucesso!',
    );

    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    if (!mounted) return;

    setState(() {
      _alunoSelecionado = null;
      _fotoCapturada = null;
      _rostoDetectado = false;
    });
  } on ApiException catch (e) {
    debugPrint(
      '========================================',
    );
    debugPrint(
      'ERRO DA API NO CADASTRO FACIAL',
    );
    debugPrint(
      'CONTEXTO: ${e.contexto}',
    );
    debugPrint(
      'STATUS: ${e.statusCode}',
    );
    debugPrint(
      'MENSAGEM: ${e.mensagemAmigavel}',
    );
    debugPrint(
      'DETALHES: ${e.detalhesBackend}',
    );
    debugPrint(
      '========================================',
    );

    if (mounted) {
      _exibirSnackBar(
        e.mensagemAmigavel,
        isErro: true,
      );
    }
  } catch (e, stackTrace) {
    debugPrint(
      '========================================',
    );
    debugPrint(
      'ERRO AO SALVAR ROSTO',
    );
    debugPrint('$e');
    debugPrint('$stackTrace');
    debugPrint(
      '========================================',
    );

    if (mounted) {
      _exibirSnackBar(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
        isErro: true,
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _salvando = false;
      });
    }
  }
}
  // ============================================================
  // TIRAR OUTRA FOTO
  // ============================================================

  void _tirarOutraFoto() {
    setState(() {
      _fotoCapturada = null;
      _rostoDetectado = false;
    });
  }

  // ============================================================
  // SELECIONAR ALUNO
  // ============================================================

  Future<void> _removerTeste(Map<String, dynamic> aluno) async {
    setState(() => _salvando = true);
    try {
      await _apiService.removerFotoTeste(int.parse(aluno['id_aluno'].toString()));
      if (!mounted) return;
      await context.read<FrequenciaController>().buscarChamada();
    } on ApiException catch (e) {
      if (mounted) _exibirSnackBar(e.mensagemAmigavel, isErro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _selecionarAluno(Map<String, dynamic> aluno) {
    if (_salvando || aluno['tem_rosto'] == true ||
        (FaceTestConfig.ativo && aluno['tem_rosto_teste'] == true)) return;
    setState(() {
      _alunoSelecionado = aluno;
      _fotoCapturada = null;
      _rostoDetectado = false;
    });
  }

  // ============================================================
  // CONVERTER ALUNOS
  // ============================================================

  List<Map<String, dynamic>> _obterAlunos(List alunos) {
    final busca = _buscaController.text.trim().toLowerCase();

    final lista = <Map<String, dynamic>>[];

    for (final aluno in alunos) {
      if (aluno is Map<String, dynamic>) {
        lista.add(aluno);
      } else if (aluno is Map) {
        lista.add(Map<String, dynamic>.from(aluno));
      } else {
        // Caso seja AlunoModel
        try {
          final dynamic a = aluno;

          lista.add(Map<String, dynamic>.from(a.toJson()));
        } catch (_) {}
      }
    }

    final filtrados = lista.where((aluno) {
      if (busca.isEmpty) {
        return true;
      }

      final nome = (aluno['nome'] ?? aluno['nome_aluno'] ?? '')
          .toString()
          .toLowerCase();

      return nome.contains(busca);
    }).toList();

    filtrados.sort((a, b) {
      final nomeA = (a['nome'] ?? a['nome_aluno'] ?? '').toString();

      final nomeB = (b['nome'] ?? b['nome_aluno'] ?? '').toString();

      return nomeA.compareTo(nomeB);
    });

    return filtrados;
  }

  // ============================================================
  // INICIAIS
  // ============================================================

  String _getIniciais(String nome) {
    final partes = nome.trim().split(' ').where((p) => p.isNotEmpty).toList();

    if (partes.isEmpty) {
      return '?';
    }

    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }

    return '${partes.first.substring(0, 1)}'
            '${partes.last.substring(0, 1)}'
        .toUpperCase();
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _exibirSnackBar(String mensagem, {bool isErro = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isErro
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensagem,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isErro ? const Color(0xFFDC2626) : _success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ============================================================
  // CABEÇALHO DE SEÇÃO (título com badge numerado)
  // ============================================================

  Widget _buildSectionHeader({
    required int numero,
    required String titulo,
    required IconData icone,
    bool concluido = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: concluido
                ? _success.withOpacity(0.15)
                : SifeTheme.primaryRed.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: concluido
                  ? _success.withOpacity(0.5)
                  : SifeTheme.primaryRed.withOpacity(0.5),
            ),
          ),
          child: concluido
              ? const Icon(Icons.check_rounded, color: _success, size: 18)
              : Text(
                  '$numero',
                  style: TextStyle(
                    color: SifeTheme.primaryRed,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Icon(icone, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARD PADRÃO DA TELA
  // ============================================================

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // CÂMERA
  // ============================================================

  Widget _buildCamera() {
    final corBorda = _fotoCapturada != null && _rostoDetectado
        ? _success
        : SifeTheme.primaryRed;

    Widget conteudo;

    if (FaceTestConfig.ativo) {
      conteudo = Image.asset(FaceTestConfig.foto, fit: BoxFit.cover);
    } else if (_inicializandoCamera) {
      conteudo = const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
      );
    } else if (!_cameraInicializada || _cameraController == null) {
      conteudo = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white38,
              size: 38,
            ),
            const SizedBox(height: 10),
            const Text(
              'Câmera indisponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _inicializarCamera,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: Colors.white70,
              ),
              label: const Text(
                'Tentar novamente',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    } else {
      conteudo = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _fotoCapturada != null
            ? Image.memory(_fotoBytes!, fit: BoxFit.cover)
            : FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
      );
    }

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 260,
        height: 260,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [corBorda, corBorda.withOpacity(0.35)],
          ),
          boxShadow: [
            BoxShadow(
              color: corBorda.withOpacity(0.35),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: conteudo,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FrequenciaController>();

    final alunos = _obterAlunos(controller.alunos);

    final etapaAlunoConcluida = _alunoSelecionado != null;
    final etapaRostoConcluida = _fotoCapturada != null && _rostoDetectado;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _bgTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Cadastro de rosto',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: .2,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top > 0 ? 8 : 20,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==============================================
                // CABEÇALHO / RESUMO DE PROGRESSO
                // ==============================================
                Text(
                  'Biometria facial',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Registrar rosto do aluno',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  FaceTestConfig.ativo
                      ? 'Simulação web: associe a foto de teste a um aluno sem cadastro. A foto testa o fluxo da chamada; o rosto real será cadastrado no APK.'
                      : 'Cadastre apenas os alunos sem rosto. Quem já possui cadastro pode usar o totem.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 16),

                // Barra de progresso das duas etapas
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressoEtapa(
                        ativo: true,
                        concluido: etapaAlunoConcluida,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildProgressoEtapa(
                        ativo: etapaAlunoConcluida,
                        concluido: etapaRostoConcluida,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==============================================
                // ETAPA 1 — SELEÇÃO DO ALUNO
                // ==============================================
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        numero: 1,
                        titulo: 'Selecione o aluno',
                        icone: Icons.person_search_rounded,
                        concluido: etapaAlunoConcluida,
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _buscaController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome...',
                          hintStyle: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.white38,
                            size: 20,
                          ),
                          suffixIcon: _buscaController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _buscaController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.black.withOpacity(0.22),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: SifeTheme.primaryRed,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      if (_carregandoAlunos)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                              strokeWidth: 2.2,
                            ),
                          ),
                        )
                      else if (alunos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.people_outline_rounded,
                                  color: Colors.white38,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Nenhum aluno encontrado',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _carregarAlunos,
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Carregar alunos',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: _cardBorder),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: alunos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final aluno = alunos[index];

                              final nome =
                                  (aluno['nome'] ??
                                          aluno['nome_aluno'] ??
                                          'Aluno')
                                      .toString();

                              final id = aluno['id_aluno'] ?? aluno['id'] ?? '';

                              final idSelecionado =
                                  _alunoSelecionado?['id_aluno'] ??
                                  _alunoSelecionado?['id'];

                              final selecionado =
                                  idSelecionado.toString() == id.toString();

                              return InkWell(
                                onTap: _salvando || aluno['tem_rosto'] == true || (FaceTestConfig.ativo && aluno['tem_rosto_teste'] == true) ? null : () => _selecionarAluno(aluno),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selecionado
                                        ? SifeTheme.primaryRed.withOpacity(0.14)
                                        : Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selecionado
                                          ? SifeTheme.primaryRed.withOpacity(
                                              0.5,
                                            )
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: selecionado
                                            ? SifeTheme.primaryRed
                                            : Colors.white.withOpacity(0.1),
                                        child: Text(
                                          _getIniciais(nome),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          nome,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: selecionado
                                                ? Colors.white
                                                : Colors.white.withOpacity(
                                                    0.85,
                                                  ),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (aluno['tem_rosto'] == true)
                                        const Text('Rosto cadastrado', style: TextStyle(color: _success, fontSize: 11))
                                      else if (FaceTestConfig.ativo && aluno['tem_rosto_teste'] == true)
                                        TextButton(
                                          onPressed: _salvando ? null : () => _removerTeste(aluno),
                                          child: const Text('Remover teste'),
                                        )
                                      else if (selecionado)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: _success,
                                          size: 20,
                                        )
                                      else
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.white.withOpacity(0.25),
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==============================================
                // ETAPA 2 — CÂMERA
                // ==============================================
                _buildCard(
                  child: Column(
                    children: [
                      _buildSectionHeader(
                        numero: 2,
                        titulo: FaceTestConfig.ativo ? 'Foto de teste — simulação web' : 'Capture o rosto',
                        icone: Icons.face_retouching_natural_rounded,
                        concluido: etapaRostoConcluida,
                      ),

                      const SizedBox(height: 20),

                      _buildCamera(),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: etapaRostoConcluida
                              ? _success.withOpacity(0.12)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              etapaRostoConcluida
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 15,
                              color: etapaRostoConcluida
                                  ? _success
                                  : Colors.white60,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              etapaRostoConcluida
                                  ? (FaceTestConfig.ativo ? 'Foto de teste selecionada' : 'Rosto detectado com sucesso')
                                  : (FaceTestConfig.ativo ? 'Associe a foto a um único aluno' : 'Posicione o rosto dentro do círculo'),
                              style: TextStyle(
                                color: etapaRostoConcluida
                                    ? _success
                                    : Colors.white60,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ==============================================
                // AÇÕES
                // ==============================================
                if (_fotoCapturada == null)
                  _buildBotaoPrimario(
                    label: FaceTestConfig.ativo ? 'USAR FOTO DE TESTE' : 'CAPTURAR ROSTO',
                    icone: Icons.camera_alt_rounded,
                    habilitado:
                        _alunoSelecionado != null && (_cameraInicializada || FaceTestConfig.ativo),
                    onPressed: _capturarEVerificarRosto,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _salvando ? null : _tirarOutraFoto,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'TIRAR OUTRA',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: .3,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: _cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildBotaoPrimario(
                          label: _salvando ? 'SALVANDO...' : 'SALVAR ROSTO',
                          icone: Icons.save_rounded,
                          habilitado: !_salvando,
                          carregando: _salvando,
                          cor: _success,
                          onPressed: _salvarCadastro,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INDICADOR DE ETAPA (barrinha de progresso)
  // ============================================================

  Widget _buildProgressoEtapa({required bool ativo, required bool concluido}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: concluido
            ? _success
            : ativo
            ? SifeTheme.primaryRed
            : Colors.white.withOpacity(0.08),
      ),
    );
  }

  // ============================================================
  // BOTÃO PRIMÁRIO PADRÃO
  // ============================================================

  Widget _buildBotaoPrimario({
    required String label,
    required IconData icone,
    required bool habilitado,
    required VoidCallback onPressed,
    bool carregando = false,
    Color? cor,
  }) {
    final corBotao = cor ?? SifeTheme.primaryRed;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: habilitado ? onPressed : null,
        icon: carregando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Icon(icone, size: 19),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: corBotao,
          disabledBackgroundColor: Colors.white.withOpacity(0.06),
          disabledForegroundColor: Colors.white38,
          foregroundColor: Colors.white,
          elevation: habilitado ? 3 : 0,
          shadowColor: corBotao.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _cameraController?.dispose();
    if (!kIsWeb) _faceDetector.close();
    _buscaController.dispose();

    super.dispose();
  }
}
