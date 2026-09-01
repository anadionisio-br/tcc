import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';
import '../models/aluno_model.dart';

class TotemFacialPage extends StatefulWidget {
  const TotemFacialPage({Key? key}) : super(key: key);

  @override
  State<TotemFacialPage> createState() => _TotemFacialPageState();
}

class _TotemFacialPageState extends State<TotemFacialPage> {
  CameraController? _cameraController;
  bool _cameraInicializada = false;
  bool _erroCamera = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableClassification: false,
    ),
  );

  bool _isProcessingFrame = false;
  bool _procurandoRosto = true;
  bool _sucesso = false;
  bool _jaRegistradoHoje = false;

  String _nomeAlunoIdentificado = "";
  String _matriculaAluno = "";

  final List<int> _alunosRegistradosRecentemente = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Captura o id_turma passado via Arguments pela TurmasPage
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final int? idTurma = args?['id_turma'];

      final controller = context.read<FrequenciaController>();
      if (idTurma != null) {
        await controller.buscarChamadaPorTurma(idTurma);
      } else {
        await controller.buscarChamada();
      }

      await _inicializarCameraComMLKit();
    });
  }

  Future<void> _inicializarCameraComMLKit() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _erroCamera = true);
        return;
      }

      final cameraFrontal = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        cameraFrontal,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _cameraInicializada = true;
          _erroCamera = false;
        });

        _cameraController!.startImageStream(_processarFrameCamera);
      }
    } catch (e) {
      debugPrint("Erro ao inicializar câmera ML Kit: $e");
      if (mounted) {
        setState(() {
          _erroCamera = true;
          _cameraInicializada = false;
        });
      }
    }
  }

  Future<void> _processarFrameCamera(CameraImage image) async {
    if (_isProcessingFrame || !_procurandoRosto) return;

    _isProcessingFrame = true;

    try {
      final inputImage = _converterCameraImageParaInputImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final Face rostroDetectado = faces.first;

        if (rostroDetectado.boundingBox.width > 80) {
          await _identificarERegistrarAluno();
        }
      }
    } catch (e) {
      debugPrint("Erro ao processar frame no ML Kit: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _identificarERegistrarAluno() async {
    if (!_procurandoRosto) return;

    setState(() {
      _procurandoRosto = false;
    });

    final controller = context.read<FrequenciaController>();

    if (controller.alunos.isEmpty) {
      _resetarModoLeitura(2000);
      return;
    }

    AlunoModel? alunoIdentificado;
    try {
      alunoIdentificado = controller.alunos.firstWhere(
        (a) => !_alunosRegistradosRecentemente.contains(a.idAluno) && a.status != 'Presente',
      );
    } catch (_) {
      try {
        alunoIdentificado = controller.alunos.firstWhere(
          (a) => !_alunosRegistradosRecentemente.contains(a.idAluno),
        );
      } catch (_) {
        alunoIdentificado = null;
      }
    }

    if (alunoIdentificado == null) {
      _resetarModoLeitura(2000);
      return;
    }

    _alunosRegistradosRecentemente.add(alunoIdentificado.idAluno);
    final bool jaEstavaPresente = alunoIdentificado.status == 'Presente';

    if (mounted) {
      setState(() {
        _sucesso = !jaEstavaPresente;
        _jaRegistradoHoje = jaEstavaPresente;
        _nomeAlunoIdentificado = alunoIdentificado!.nome;
        _matriculaAluno = "Matrícula: ${alunoIdentificado.idAluno}";
      });
    }

    if (!jaEstavaPresente) {
      try {
        await controller.registrarPresencaFacial(alunoIdentificado.idAluno);
      } catch (e) {
        debugPrint("Erro ao registrar no Laravel: $e");
      }
    }

    _resetarModoLeitura(3000);
  }

  void _resetarModoLeitura(int delayMs) {
    Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        setState(() {
          _sucesso = false;
          _jaRegistradoHoje = false;
          _procurandoRosto = true;
        });
      }
    });
  }

  InputImage? _converterCameraImageParaInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation = _cameraController!.description.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color corFundo = SifeTheme.textDark;
    if (_sucesso) {
      corFundo = const Color(0xFF12B886);
    } else if (_jaRegistradoHoje) {
      corFundo = const Color(0xFFF59E0B);
    }

    return Scaffold(
      backgroundColor: corFundo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'TERMINAL BIOMÉTRICO FACIAL',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _procurandoRosto ? Colors.greenAccent : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _procurandoRosto ? "DETECTOR ATIVO (ML KIT)" : "PROCESSANDO ROSTO...",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),

            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (_sucesso || _jaRegistradoHoje) ? Colors.white : SifeTheme.primaryRed,
                        width: 4,
                      ),
                    ),
                    child: ClipOval(
                      child: _erroCamera
                          ? const Center(
                              child: Icon(Icons.videocam_off, color: Colors.red, size: 36),
                            )
                          : (_cameraInicializada && _cameraController != null && _cameraController!.value.isInitialized
                              ? CameraPreview(_cameraController!)
                              : const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )),
                    ),
                  ),
                  if (_procurandoRosto)
                    Positioned(
                      top: 140,
                      child: Container(
                        width: 260,
                        height: 3,
                        decoration: BoxDecoration(
                          color: SifeTheme.primaryRed,
                          boxShadow: [
                            BoxShadow(
                              color: SifeTheme.primaryRed,
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _sucesso
                    ? Column(
                        key: const ValueKey('sucesso'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(FontAwesomeIcons.solidCircleCheck, color: Colors.white, size: 50),
                          const SizedBox(height: 16),
                          const Text(
                            'ENTRADA CONFIRMADA',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _nomeAlunoIdentificado,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _matriculaAluno,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                          ),
                        ],
                      )
                    : _jaRegistradoHoje
                        ? Column(
                            key: const ValueKey('jaRegistrado'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.white, size: 50),
                              const SizedBox(height: 16),
                              const Text(
                                'PRESENÇA JÁ REGISTRADA',
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _nomeAlunoIdentificado,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _matriculaAluno,
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                              ),
                            ],
                          )
                        : Column(
                            key: const ValueKey('leitor'),
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(SifeTheme.primaryRed)),
                              SizedBox(height: 24),
                              Text(
                                'Posicione seu rosto dentro do círculo',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}