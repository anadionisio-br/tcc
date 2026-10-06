import 'dart:async';
import 'package:flutter/services.dart';
import '../config/face_test_config.dart';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';
import '../services/api_service.dart';
import '../services/face_recognition_service.dart';

class TotemFacialPage extends StatefulWidget {
  const TotemFacialPage({Key? key}) : super(key: key);

  @override
  State<TotemFacialPage> createState() => _TotemFacialPageState();
}

class _TotemFacialPageState extends State<TotemFacialPage> {
  CameraController? _cameraController;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableClassification: false,
    ),
  );

  final FaceRecognitionService _faceService = FaceRecognitionService();

  Timer? _resetTimer;

  bool _carregandoChamada = true;
  bool _cameraInicializada = false;
  bool _erroCamera = false;
  bool _isProcessingFrame = false;
  bool _procurandoRosto = true;
  bool _processandoReconhecimento = false;
  bool _sucesso = false;
  bool _jaRegistradoHoje = false;
  bool _streamIniciado = false;

  String _nomeAlunoIdentificado = '';
  String _matriculaAluno = '';

  final Set<int> _alunosRegistradosRecentemente = <int>{};

  static const Color _bgIdle = Color(0xFF11151C);
  static const Color _bgIdleBottom = Color(0xFF1B212B);

  static const Color _corSucesso = Color(0xFF16A34A);
  static const Color _corSucessoEscuro = Color(0xFF0F7A38);

  static const Color _corAviso = Color(0xFFF59E0B);
  static const Color _corAvisoEscuro = Color(0xFFB6790A);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializar();
    });
  }

  Future<void> _inicializar() async {
    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      final int? idTurma = _converterParaInt(args?['id_turma']);

      final controller = context.read<FrequenciaController>();

      if (idTurma != null) {
        await controller.buscarChamadaPorTurma(idTurma);
      } else {
        await controller.buscarChamada();
      }

      if (!mounted) return;
      setState(() => _carregandoChamada = false);
      if (controller.erroChamada != null || controller.turmaSelecionada == null) {
        setState(() => _procurandoRosto = false);
        _mostrarFalha(controller.erroChamada ?? 'Selecione uma turma antes de abrir o totem.');
        return;
      }
      if (!kIsWeb) await _inicializarCameraComMLKit();
    } catch (e, stackTrace) {
      debugPrint('Erro na inicialização do totem: $e');
      debugPrint('$stackTrace');

      if (mounted) {
        setState(() {
          _erroCamera = true;
          _carregandoChamada = false;
        });
      }
    }
  }

  int? _converterParaInt(dynamic valor) {
    if (valor == null) return null;

    if (valor is int) {
      return valor;
    }

    return int.tryParse(valor.toString());
  }

  // ============================================================
  // CÂMERA
  // ============================================================

  Future<void> _inicializarCameraComMLKit() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint('Nenhuma câmera encontrada.');

        if (mounted) {
          setState(() {
            _erroCamera = true;
            _cameraInicializada = false;
          });
        }

        return;
      }

      final cameraFrontal = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        cameraFrontal,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      _cameraController = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraInicializada = true;
        _erroCamera = false;
      });

      await controller.startImageStream(_processarFrameCamera);

      _streamIniciado = true;
    } catch (e, stackTrace) {
      debugPrint('Erro ao inicializar câmera ML Kit: $e');
      debugPrint('$stackTrace');

      if (mounted) {
        setState(() {
          _erroCamera = true;
          _cameraInicializada = false;
        });
      }
    }
  }

  Future<void> _processarFrameCamera(CameraImage image) async {
    if (_isProcessingFrame) return;
    if (!_procurandoRosto) return;
    if (_processandoReconhecimento) return;

    _isProcessingFrame = true;

    try {
      final inputImage = _converterCameraImageParaInputImage(image);

      if (inputImage == null) {
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return;
      }

      final face = faces.first;

      if (face.boundingBox.width < 80) {
        return;
      }

      await _identificarERegistrarAluno();
    } catch (e, stackTrace) {
      debugPrint('Erro ao processar frame no ML Kit: $e');
      debugPrint('$stackTrace');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ============================================================
  // RECONHECIMENTO FACIAL
  // ============================================================

  Future<void> _identificarERegistrarAluno() async {
    if (!_procurandoRosto) return;
    if (_processandoReconhecimento) return;

    final camera = _cameraController;

    if (!FaceTestConfig.ativo && (camera == null || !camera.value.isInitialized)) {
      return;
    }

    final frequenciaController = context.read<FrequenciaController>();

    final turmaSelecionada = frequenciaController.turmaSelecionada;

    if (turmaSelecionada == null) {
      _mostrarFalha('Nenhuma turma foi selecionada.');
      return;
    }

    _processandoReconhecimento = true;

    _resetTimer?.cancel();

    if (mounted) {
      setState(() {
        _procurandoRosto = false;
        _sucesso = false;
        _jaRegistradoHoje = false;
      });
    }

    try {
      Map<String, dynamic> resultado;
      if (FaceTestConfig.ativo) {
        final bytes = (await rootBundle.load(FaceTestConfig.foto)).buffer.asUint8List();
        resultado = await ApiService().enviarFotoTeste(bytes: bytes, idTurma: turmaSelecionada);
      } else {
        await _pararImageStream();
        final foto = await camera!.takePicture();
        final bytes = await foto.readAsBytes();
        final embedding = await _faceService.extrairRosto(bytes);
        if (embedding == null || embedding.isEmpty) {
          _mostrarFalha('Não foi possível identificar o rosto.');
          return;
        }
        resultado = await ApiService().reconhecerRosto(
          embedding: embedding, idTurma: turmaSelecionada,
        );
      }

      final reconhecido = resultado['reconhecido'] == true;

      if (!reconhecido) {
        _mostrarFalha(
          resultado['message']?.toString() ??
              'Rosto não reconhecido.',
        );

        return;
      }

      final aluno = resultado['aluno'];

      if (aluno is! Map) {
        _mostrarFalha(
          'A API não retornou os dados do aluno identificado.',
        );

        return;
      }

      final idAluno = _converterParaInt(aluno['id_aluno']);

      final nome = aluno['nome']?.toString().trim();

      final nomeAluno =
          (nome == null || nome.isEmpty) ? 'Aluno' : nome;

      if (idAluno == null || idAluno <= 0) {
        _mostrarFalha('Aluno identificado possui ID inválido.');

        return;
      }

      final indice = frequenciaController.alunos.indexWhere((a) => a.idAluno == idAluno);
      if (indice < 0) {
        _mostrarFalha('Este aluno não pertence à chamada atual.');
        return;
      }
      if (frequenciaController.alunos[indice].status == 'Presente') {
        _mostrarJaRegistrado(nomeAluno, idAluno);
        return;
      }

      // Evita registrar novamente enquanto o totem está em uso.
      final jaRegistradoRecentemente =
          _alunosRegistradosRecentemente.contains(idAluno);

      if (jaRegistradoRecentemente) {
        _mostrarJaRegistrado(
          nomeAluno,
          idAluno,
        );

        return;
      }

      final sucesso = await frequenciaController.registrarPresencaFacial(
        idAluno,
        testeWeb: FaceTestConfig.ativo,
        viaTotem: true,
      );

      if (!sucesso) {
        _mostrarFalha(
          'Não foi possível registrar a presença de $nomeAluno.',
        );

        return;
      }

      _alunosRegistradosRecentemente.add(idAluno);

      if (!mounted) return;

      setState(() {
        _sucesso = true;
        _jaRegistradoHoje = false;
        _nomeAlunoIdentificado = nomeAluno;
        _matriculaAluno = 'Matrícula: $idAluno';
      });
    } catch (e, stackTrace) {
      debugPrint('ERRO NO RECONHECIMENTO: $e');
      debugPrint('$stackTrace');

      _mostrarFalha(
        e is ApiException ? e.mensagemAmigavel : 'Erro ao realizar reconhecimento facial.',
      );
    } finally {
      _processandoReconhecimento = false;

      _resetarModoLeitura(3000);
    }
  }

  // ============================================================
  // FEEDBACK
  // ============================================================

  void _mostrarFalha(String mensagem) {
    if (!mounted) return;

    setState(() {
      _sucesso = false;
      _jaRegistradoHoje = false;
      _nomeAlunoIdentificado = mensagem;
      _matriculaAluno = '';
    });
  }

  void _mostrarJaRegistrado(String nome, int idAluno) {
    if (!mounted) return;

    setState(() {
      _sucesso = false;
      _jaRegistradoHoje = true;
      _nomeAlunoIdentificado = nome;
      _matriculaAluno = 'Matrícula: $idAluno';
    });
  }

  void _resetarModoLeitura(int delayMs) {
    _resetTimer?.cancel();

    _resetTimer = Timer(
      Duration(milliseconds: delayMs),
      () async {
        if (!mounted) return;

        setState(() {
          _sucesso = false;
          _jaRegistradoHoje = false;
          _nomeAlunoIdentificado = '';
          _matriculaAluno = '';
          _procurandoRosto = true;
        });

        if (!kIsWeb) await _iniciarImageStream();
      },
    );
  }

  // ============================================================
  // IMAGE STREAM
  // ============================================================

  Future<void> _pararImageStream() async {
    final camera = _cameraController;

    if (camera == null) return;

    if (!_streamIniciado) return;

    try {
      await camera.stopImageStream();
    } catch (e) {
      debugPrint('Erro ao parar image stream: $e');
    } finally {
      _streamIniciado = false;
    }
  }

  Future<void> _iniciarImageStream() async {
    final camera = _cameraController;

    if (camera == null) return;
    if (!camera.value.isInitialized) return;
    if (_streamIniciado) return;

    try {
      await camera.startImageStream(_processarFrameCamera);

      _streamIniciado = true;
    } catch (e) {
      debugPrint('Erro ao iniciar image stream: $e');
    }
  }

  // ============================================================
  // CONVERSÃO CAMERA IMAGE -> ML KIT
  // ============================================================

  InputImage? _converterCameraImageParaInputImage(
    CameraImage image,
  ) {
    final camera = _cameraController;

    if (camera == null) {
      return null;
    }

    if (image.planes.isEmpty) {
      return null;
    }

    final sensorOrientation =
        camera.description.sensorOrientation;

    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation);

    if (rotation == null) {
      return null;
    }

    final format =
        InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null) {
      return null;
    }

    final WriteBuffer allBytes = WriteBuffer();

    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _resetTimer?.cancel();

    if (_streamIniciado) {
      _cameraController?.stopImageStream();
    }

    _cameraController?.dispose();

    if (!kIsWeb) _faceDetector.close();

    super.dispose();
  }

  // ============================================================
  // CORES
  // ============================================================

  List<Color> get _gradienteFundo {
    if (_sucesso) {
      return [
        _corSucesso,
        _corSucessoEscuro,
      ];
    }

    if (_jaRegistradoHoje) {
      return [
        _corAviso,
        _corAvisoEscuro,
      ];
    }

    return [
      _bgIdle,
      _bgIdleBottom,
    ];
  }

  Color get _corDestaque {
    if (_sucesso) {
      return Colors.white;
    }

    if (_jaRegistradoHoje) {
      return Colors.white;
    }

    return SifeTheme.primaryRed;
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatusPill() {
    final ativo = _procurandoRosto;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(ativo: ativo),
          const SizedBox(width: 9),
          Text(
            ativo
                ? (FaceTestConfig.ativo ? 'SIMULAÇÃO WEB' : 'DETECTOR ATIVO')
                : 'PROCESSANDO ROSTO...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CÂMERA NA TELA
  // ============================================================

  Widget _buildCamera() {
    Widget conteudo;

    if (FaceTestConfig.ativo) {
      conteudo = ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(FaceTestConfig.foto, fit: BoxFit.cover),
      );
    } else if (_erroCamera) {
      conteudo = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_rounded,
              color: Colors.white54,
              size: 34,
            ),
            SizedBox(height: 8),
            Text(
              'Câmera indisponível',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else if (_cameraInicializada &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      conteudo = ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CameraPreview(
          _cameraController!,
        ),
      );
    } else {
      conteudo = const Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2.4,
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 270,
          height: 270,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _corDestaque,
                _corDestaque.withOpacity(0.35),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _corDestaque.withOpacity(0.35),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(22),
            ),
            child: conteudo,
          ),
        ),

        if (_procurandoRosto && !_erroCamera)
          _ScanningLine(
            color: _corDestaque,
          ),
      ],
    );
  }

  // ============================================================
  // RESULTADO
  // ============================================================

  Widget _buildResultado() {
    Widget conteudo;

    if (_sucesso) {
      conteudo = Column(
        key: const ValueKey('sucesso'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.solidCircleCheck,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ENTRADA CONFIRMADA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _nomeAlunoIdentificado,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          _buildChipMatricula(),
        ],
      );
    } else if (_jaRegistradoHoje) {
      conteudo = Column(
        key: const ValueKey('jaRegistrado'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.info_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PRESENÇA JÁ REGISTRADA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _nomeAlunoIdentificado,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          _buildChipMatricula(),
        ],
      );
    } else if (_nomeAlunoIdentificado.isNotEmpty) {
      // Mensagem de erro
      conteudo = Column(
        key: const ValueKey('erro'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _nomeAlunoIdentificado,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      );
    } else {
      conteudo = Column(
        key: const ValueKey('leitor'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                SifeTheme.primaryRed,
              ),
              strokeWidth: 2.6,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            FaceTestConfig.ativo ? 'Clique em TESTAR FOTO NO TOTEM' : 'Posicione seu rosto dentro do círculo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            FaceTestConfig.ativo ? 'Cadastre a foto em um aluno desta turma primeiro' : 'O reconhecimento é automático',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12.5,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 26,
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: conteudo,
      ),
    );
  }

  Widget _buildChipMatricula() {
    if (_matriculaAluno.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _matriculaAluno,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _bgIdle,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TERMINAL BIOMÉTRICO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Reconhecimento facial',
              style: TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _gradienteFundo,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 24,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      _buildStatusPill(),
                      const SizedBox(height: 8),
                      Text(
                        'Turma ${context.watch<FrequenciaController>().turmaSelecionada ?? "—"} • '
                        '${context.watch<FrequenciaController>().dataFormatada}',
                        style: const TextStyle(color: Colors.white70),
                      ),

                      const SizedBox(height: 42),

                      _buildCamera(),
                      if (FaceTestConfig.ativo) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Foto de teste • simulação, sem biometria real.\nA presença será salva na chamada selecionada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _carregandoChamada || !_procurandoRosto || _processandoReconhecimento
                              ? null : _identificarERegistrarAluno,
                          icon: const Icon(Icons.face),
                          label: const Text('TESTAR FOTO NO TOTEM'),
                        ),
                      ],

                      const SizedBox(height: 42),

                      _buildResultado(),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PONTO PULSANTE
// ============================================================

class _PulsingDot extends StatefulWidget {
  final bool ativo;

  const _PulsingDot({
    required this.ativo,
  });

  @override
  State<_PulsingDot> createState() =>
      _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.ativo
        ? const Color(0xFF4ADE80)
        : const Color(0xFFF87171);

    if (!widget.ativo) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
        ),
      );
    }

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1.0,
      ).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: cor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ============================================================
// LINHA DE VARREDURA
// ============================================================

class _ScanningLine extends StatefulWidget {
  final Color color;

  const _ScanningLine({
    required this.color,
  });

  @override
  State<_ScanningLine> createState() =>
      _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offsetY =
            -95 + (_controller.value * 190);

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Container(
            width: 232,
            height: 2.5,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color:
                      widget.color.withOpacity(0.7),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
