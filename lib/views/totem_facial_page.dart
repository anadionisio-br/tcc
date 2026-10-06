import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../config/face_test_config.dart';
import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';
import '../services/api_service.dart';
import '../services/face_recognition_service.dart';

class TotemFacialPage extends StatefulWidget {
  const TotemFacialPage({super.key});

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

  static const Color _bgTop = Color(0xFF07101F);
  static const Color _bgBottom = Color(0xFF101C31);

  static const Color _corSucesso = Color(0xFF22C55E);
  static const Color _corAviso = Color(0xFFF59E0B);
  static const Color _corErro = Color(0xFFEF4444);

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

      setState(() {
        _carregandoChamada = false;
      });

      if (controller.erroChamada != null ||
          controller.turmaSelecionada == null) {
        setState(() {
          _procurandoRosto = false;
        });

        _mostrarFalha(
          controller.erroChamada ??
              'Selecione uma turma antes de abrir o totem.',
        );

        return;
      }

      if (!kIsWeb) {
        await _inicializarCameraComMLKit();
      }
    } catch (e, stackTrace) {
      debugPrint('Erro na inicialização do totem: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _erroCamera = true;
        _carregandoChamada = false;
        _procurandoRosto = false;
      });
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
        if (mounted) {
          setState(() {
            _erroCamera = true;
            _cameraInicializada = false;
          });
        }

        return;
      }

      final cameraFrontal = cameras.firstWhere(
        (camera) =>
            camera.lensDirection == CameraLensDirection.front,
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

      await controller.startImageStream(
        _processarFrameCamera,
      );

      _streamIniciado = true;
    } catch (e, stackTrace) {
      debugPrint('Erro ao inicializar câmera: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _erroCamera = true;
        _cameraInicializada = false;
      });
    }
  }

  Future<void> _processarFrameCamera(CameraImage image) async {
    if (_isProcessingFrame) return;
    if (!_procurandoRosto) return;
    if (_processandoReconhecimento) return;

    _isProcessingFrame = true;

    try {
      final inputImage =
          _converterCameraImageParaInputImage(image);

      if (inputImage == null) {
        return;
      }

      final faces =
          await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return;
      }

      final face = faces.first;

      if (face.boundingBox.width < 80) {
        return;
      }

      await _identificarERegistrarAluno();
    } catch (e, stackTrace) {
      debugPrint('Erro ao processar frame: $e');
      debugPrint('$stackTrace');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ============================================================
  // RECONHECIMENTO
  // ============================================================

  Future<void> _identificarERegistrarAluno() async {
    if (!_procurandoRosto) return;
    if (_processandoReconhecimento) return;

    final camera = _cameraController;

    if (!FaceTestConfig.ativo &&
        (camera == null || !camera.value.isInitialized)) {
      return;
    }

    final frequenciaController =
        context.read<FrequenciaController>();

    final turmaSelecionada =
        frequenciaController.turmaSelecionada;

    if (turmaSelecionada == null) {
      _mostrarFalha(
        'Nenhuma turma foi selecionada.',
      );
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
        final bytes = (await rootBundle
                .load(FaceTestConfig.foto))
            .buffer
            .asUint8List();

        resultado = await ApiService().enviarFotoTeste(
          bytes: bytes,
          idTurma: turmaSelecionada,
        );
      } else {
        await _pararImageStream();

        final foto = await camera!.takePicture();

        final bytes = await foto.readAsBytes();

        final embedding =
            await _faceService.extrairRosto(bytes);

        if (embedding == null || embedding.isEmpty) {
          _mostrarFalha(
            'Não foi possível identificar o rosto.',
          );
          return;
        }

        resultado = await ApiService().reconhecerRosto(
          embedding: embedding,
          idTurma: turmaSelecionada,
        );
      }

      final reconhecido =
          resultado['reconhecido'] == true;

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

      final idAluno =
          _converterParaInt(aluno['id_aluno']);

      final nome =
          aluno['nome']?.toString().trim();

      final nomeAluno =
          (nome == null || nome.isEmpty)
              ? 'Aluno'
              : nome;

      if (idAluno == null || idAluno <= 0) {
        _mostrarFalha(
          'Aluno identificado possui ID inválido.',
        );
        return;
      }

      final indice =
          frequenciaController.alunos.indexWhere(
        (a) => a.idAluno == idAluno,
      );

      if (indice < 0) {
        _mostrarFalha(
          'Este aluno não pertence à chamada atual.',
        );
        return;
      }

      if (frequenciaController
              .alunos[indice]
              .status ==
          'Presente') {
        _mostrarJaRegistrado(
          nomeAluno,
          idAluno,
        );
        return;
      }

      final jaRegistradoRecentemente =
          _alunosRegistradosRecentemente
              .contains(idAluno);

      if (jaRegistradoRecentemente) {
        _mostrarJaRegistrado(
          nomeAluno,
          idAluno,
        );
        return;
      }

      final sucesso =
          await frequenciaController
              .registrarPresencaFacial(
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
        e is ApiException
            ? e.mensagemAmigavel
            : 'Erro ao realizar reconhecimento facial.',
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

  void _mostrarJaRegistrado(
    String nome,
    int idAluno,
  ) {
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

        if (!kIsWeb) {
          await _iniciarImageStream();
        }
      },
    );
  }

  // ============================================================
  // STREAM
  // ============================================================

  Future<void> _pararImageStream() async {
    final camera = _cameraController;

    if (camera == null) return;
    if (!_streamIniciado) return;

    try {
      await camera.stopImageStream();
    } catch (e) {
      debugPrint(
        'Erro ao parar image stream: $e',
      );
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
      await camera.startImageStream(
        _processarFrameCamera,
      );

      _streamIniciado = true;
    } catch (e) {
      debugPrint(
        'Erro ao iniciar image stream: $e',
      );
    }
  }

  // ============================================================
  // CONVERSÃO ML KIT
  // ============================================================

  InputImage? _converterCameraImageParaInputImage(
    CameraImage image,
  ) {
    final camera = _cameraController;

    if (camera == null) return null;
    if (image.planes.isEmpty) return null;

    final sensorOrientation =
        camera.description.sensorOrientation;

    final rotation =
        InputImageRotationValue.fromRawValue(
      sensorOrientation,
    );

    if (rotation == null) return null;

    final format =
        InputImageFormatValue.fromRawValue(
      image.format.raw,
    );

    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();

    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes =
        allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        rotation: rotation,
        format: format,
        bytesPerRow:
            image.planes.first.bytesPerRow,
      ),
    );
  }

  // ============================================================
  // CORES / ESTADOS
  // ============================================================

  bool get _mostrandoResultado =>
      _sucesso ||
      _jaRegistradoHoje ||
      _nomeAlunoIdentificado.isNotEmpty;

  Color get _corDestaque {
    if (_sucesso) return _corSucesso;
    if (_jaRegistradoHoje) return _corAviso;
    if (_nomeAlunoIdentificado.isNotEmpty) {
      return _corErro;
    }

    return Colors.white.withOpacity(0.85);
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatusPill() {
    final ativo = _procurandoRosto;

    return Semantics(
      label: ativo
          ? 'Câmera ativa aguardando reconhecimento'
          : 'Processando reconhecimento facial',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDot(ativo: ativo),
            const SizedBox(width: 9),
            Text(
              ativo
                  ? (FaceTestConfig.ativo
                      ? 'Modo simulação'
                      : 'Câmera ativa')
                  : 'Reconhecendo rosto...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTurma(
    FrequenciaController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Icon(
            Icons.school_rounded,
            size: 17,
            color: Colors.white.withOpacity(0.65),
          ),
          Text(
            'Turma ${controller.turmaSelecionada ?? "—"}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          Text(
            controller.dataFormatada,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CÂMERA
  // ============================================================

  Widget _buildCamera({
    required double tamanhoCamera,
  }) {
    final espacoAnel = tamanhoCamera >= 360
        ? 16.0
        : 12.0;

    final diametroInterno =
        tamanhoCamera - espacoAnel * 2;

    final processando =
        !_procurandoRosto &&
        !_mostrandoResultado;

    Widget conteudo;

    if (FaceTestConfig.ativo) {
      conteudo = Image.asset(
        FaceTestConfig.foto,
        fit: BoxFit.cover,
      );
    } else if (_erroCamera) {
      conteudo = _buildCameraErro();
    } else if (_cameraInicializada &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      final preview =
          _cameraController!.value.previewSize;

      conteudo = preview == null
          ? CameraPreview(_cameraController!)
          : FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: preview.height,
                height: preview.width,
                child: CameraPreview(
                  _cameraController!,
                ),
              ),
            );
    } else {
      conteudo = const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.4,
        ),
      );
    }

    return Semantics(
      label: FaceTestConfig.ativo
          ? 'Foto de teste para reconhecimento facial'
          : 'Câmera para reconhecimento facial',
      child: SizedBox(
        width: tamanhoCamera,
        height: tamanhoCamera,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: diametroInterno,
              height: diametroInterno,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: conteudo,
              ),
            ),

            if (processando)
              Container(
                width: diametroInterno,
                height: diametroInterno,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.50),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),

            Positioned.fill(
              child: CustomPaint(
                painter: _AnelPainter(
                  color: _corDestaque,
                  completo: _mostrandoResultado,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _corErro.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white70,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Câmera indisponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Verifique a permissão da câmera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RESULTADO
  // ============================================================

  Widget _buildResultado() {
    Widget conteudo;

    if (_sucesso) {
      conteudo = _resultadoComIcone(
        key: const ValueKey('sucesso'),
        icone: const FaIcon(
          FontAwesomeIcons.solidCircleCheck,
          color: Colors.white,
          size: 30,
        ),
        titulo: 'Entrada confirmada',
        nome: _nomeAlunoIdentificado,
      );
    } else if (_jaRegistradoHoje) {
      conteudo = _resultadoComIcone(
        key: const ValueKey('registrado'),
        icone: const Icon(
          Icons.info_rounded,
          color: Colors.white,
          size: 30,
        ),
        titulo: 'Presença já registrada',
        nome: _nomeAlunoIdentificado,
      );
    } else if (_nomeAlunoIdentificado.isNotEmpty) {
      conteudo = _resultadoComIcone(
        key: const ValueKey('erro'),
        icone: const Icon(
          Icons.error_outline_rounded,
          color: Colors.white,
          size: 30,
        ),
        titulo: _nomeAlunoIdentificado,
        tamanhoTitulo: 16,
      );
    } else {
      conteudo = _buildEstadoAguardando();
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 560,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _mostrandoResultado
            ? _corDestaque.withOpacity(0.09)
            : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _mostrandoResultado
              ? _corDestaque.withOpacity(0.35)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(
          milliseconds: 250,
        ),
        child: conteudo,
      ),
    );
  }

  Widget _resultadoComIcone({
    required Key key,
    required Widget icone,
    required String titulo,
    String? nome,
    double tamanhoTitulo = 20,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _corDestaque,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _corDestaque.withOpacity(0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(child: icone),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: tamanhoTitulo,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (nome != null) ...[
          const SizedBox(height: 7),
          Text(
            nome,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          _buildChipMatricula(),
        ],
      ],
    );
  }

  Widget _buildEstadoAguardando() {
    return Column(
      key: const ValueKey('aguardando'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: SifeTheme.primaryRed.withOpacity(0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.center_focus_strong_rounded,
            color: SifeTheme.primaryRed,
            size: 26,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          FaceTestConfig.ativo
              ? 'Pronto para testar'
              : 'Posicione seu rosto no círculo',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          FaceTestConfig.ativo
              ? 'Use o botão abaixo para executar a simulação.'
              : 'O reconhecimento será realizado automaticamente.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.52),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildChipMatricula() {
    if (_matriculaAluno.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _matriculaAluno,
        style: TextStyle(
          color: Colors.white.withOpacity(0.90),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // TESTE WEB
  // ============================================================

  Widget _buildControlesTeste() {
    if (!FaceTestConfig.ativo) {
      return const SizedBox.shrink();
    }

    final habilitado =
        !_carregandoChamada &&
        _procurandoRosto &&
        !_processandoReconhecimento;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.science_outlined,
                size: 17,
                color: Colors.white.withOpacity(0.65),
              ),
              const SizedBox(width: 7),
              Text(
                'Modo de teste',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A simulação utiliza uma foto de teste e não biometria real.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.48),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: habilitado
                  ? _identificarERegistrarAluno
                  : null,
              icon: const Icon(
                Icons.face_rounded,
                size: 19,
              ),
              label: const Text(
                'Testar foto no totem',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    SifeTheme.primaryRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    Colors.white.withOpacity(0.08),
                disabledForegroundColor:
                    Colors.white.withOpacity(0.35),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Material(
          color: Colors.white.withOpacity(0.07),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Totem de presença',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Reconhecimento facial',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.face_retouching_natural_rounded,
            color: Colors.white70,
            size: 21,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LAYOUT PRINCIPAL
  // ============================================================

  Widget _buildConteudoResponsivo(
    BuildContext context,
    FrequenciaController frequencia,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largura = constraints.maxWidth;
        final altura = constraints.maxHeight;

        final tablet = largura >= 600;

        final paisagem =
            largura > altura && largura >= 700;

        final duasColunas =
            paisagem || largura >= 900;

        double tamanhoCamera;

        if (duasColunas) {
          tamanhoCamera = (altura * 0.62)
              .clamp(240.0, 470.0)
              .toDouble();
        } else if (tablet) {
          tamanhoCamera = (largura * 0.50)
              .clamp(300.0, 440.0)
              .toDouble();
        } else {
          tamanhoCamera = (largura * 0.74)
              .clamp(220.0, 330.0)
              .toDouble();
        }

        final status = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusPill(),
            const SizedBox(height: 12),
            _buildInfoTurma(frequencia),
            const SizedBox(height: 22),
            _buildResultado(),
          ],
        );

        final camera = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCamera(
              tamanhoCamera: tamanhoCamera,
            ),
            _buildControlesTeste(),
          ],
        );

        if (duasColunas) {
          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 5,
                child: camera,
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: status,
              ),
            ],
          );
        }

        return Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            status,
            const SizedBox(height: 28),
            camera,
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final frequencia =
        context.watch<FrequenciaController>();

    return Scaffold(
      backgroundColor: _bgTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _bgTop,
              _bgBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  8,
                ),
                child: _buildHeader(),
              ),
              Expanded(
                child: _carregandoChamada
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : LayoutBuilder(
                        builder:
                            (context, constraints) {
                          return SingleChildScrollView(
                            physics:
                                const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(
                              20,
                              10,
                              20,
                              28,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(
                                  maxWidth: 1120,
                                ),
                                child:
                                    _buildConteudoResponsivo(
                                  context,
                                  frequencia,
                                ),
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

    if (!kIsWeb) {
      _faceDetector.close();
    }

    super.dispose();
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

class _PulsingDotState
    extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds: 1100,
    ),
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
        : const Color(0xFFFBBF24);

    final ponto = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
      ),
    );

    if (!widget.ativo) {
      return ponto;
    }

    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.4,
        end: 1,
      ).animate(_controller),
      child: ponto,
    );
  }
}

// ============================================================
// ANEL
// ============================================================

class _AnelPainter extends CustomPainter {
  final Color color;
  final bool completo;

  const _AnelPainter({
    required this.color,
    required this.completo,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final centro = size.center(Offset.zero);

    final raio = size.width / 2 - 4;

    final area = Rect.fromCircle(
      center: centro,
      radius: raio,
    );

    if (completo) {
      canvas.drawCircle(
        centro,
        raio,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );

      return;
    }

    canvas.drawCircle(
      centro,
      raio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withOpacity(0.22),
    );

    final marca = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5
      ..color = color;

    const pi = 3.14159265;
    const varredura = pi / 5;

    for (var i = 0; i < 4; i++) {
      final meio =
          -pi / 4 + i * (pi / 2);

      canvas.drawArc(
        area,
        meio - varredura / 2,
        varredura,
        false,
        marca,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _AnelPainter antigo,
  ) {
    return antigo.color != color ||
        antigo.completo != completo;
  }
}
