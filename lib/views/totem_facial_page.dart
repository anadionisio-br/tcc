import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
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
  bool _procurandoRosto = true;
  bool _sucesso = false;
  String _nomeAlunoIdentificado = "";
  String _matriculaAluno = "";
  
  Timer? _timerLoop;

  @override
  void initState() {
    super.initState();
    // Garante que o Flutter carregou a árvore de elementos antes de ativar a câmera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarCameraNativa();
    });
  }

  Future<void> _inicializarCameraNativa() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _erroCamera = true);
        return;
      }

      // Procura especificamente a câmera frontal
      final cameraFrontal = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        cameraFrontal,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, // Garante compatibilidade visual
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _cameraInicializada = true;
        });
        _iniciarCicloLeitura();
      }
    } catch (e) {
      debugPrint("Erro crítico ao inicializar câmera: $e");
      if (mounted) {
        setState(() => _erroCamera = true);
      }
    }
  }

  @override
  void dispose() {
    _timerLoop?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  void _iniciarCicloLeitura() {
    if (!mounted) return;
    
    setState(() {
      _procurandoRosto = true;
      _sucesso = false;
    });

    _timerLoop = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;

      final controller = context.read<FrequenciaController>();
      if (controller.alunos.isEmpty) return;

      AlunoModel? alunoQueChegou;
      try {
        alunoQueChegou = controller.alunos.firstWhere((a) => a.status != 'Presente');
      } catch (_) {
        alunoQueChegou = controller.alunos.first;
      }

      setState(() {
        _procurandoRosto = false;
        _sucesso = true;
        _nomeAlunoIdentificado = alunoQueChegou!.nome;
        _matriculaAluno = "Matrícula: ${alunoQueChegou.idAluno}";
      });

      if (alunoQueChegou.status != 'Presente') {
        controller.alternarStatus(alunoQueChegou.idAluno);
      }

      Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _iniciarCicloLeitura();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _sucesso ? const Color(0xFF12B886) : SifeTheme.textDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'TERMINAL DE FREQUÊNCIA FACIAL', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge superior
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
                      color: _procurandoRosto ? Colors.orange : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _procurandoRosto ? "AGUARDANDO APROXIMAÇÃO..." : "REGISTRANDO PRESENÇA...",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),

            // --- SCANNER CIRCULAR COM FEEDBACK DE ERRO ---
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
                        color: _sucesso ? Colors.white : SifeTheme.primaryRed,
                        width: 4,
                      ),
                    ),
                    child: ClipOval(
                      child: _erroCamera
                          ? const Center(
                              child: Text(
                                'Erro ao acessar\na câmera frontal',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            )
                          : (_cameraInicializada && _cameraController != null
                              ? CameraPreview(_cameraController!) // Abre a câmera real aqui
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

            // --- PAINEL DE INFORMAÇÕES DO ALUNO ---
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
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                            'Olhe para a câmera para registrar sua entrada',
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