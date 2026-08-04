import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:dio/dio.dart';
import '../config/theme.dart';

class CadastroRostoPage extends StatefulWidget {
  const CadastroRostoPage({Key? key}) : super(key: key);

  @override
  State<CadastroRostoPage> createState() => _CadastroRostoPageState();
}

class _CadastroRostoPageState extends State<CadastroRostoPage> {
  CameraController? _cameraController;
  bool _cameraInicializada = false;
  
  final TextEditingController _nomeController = TextEditingController();
  
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _rostoDetectado = false;
  bool _salvando = false;
  XFile? _fotoCapturada;

  @override
  void initState() {
    super.initState();
    _inicializarCamera();
  }

  Future<void> _inicializarCamera() async {
    try {
      final cameras = await availableCameras();
      final cameraFrontal = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        cameraFrontal,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _cameraInicializada = true);
      }
    } catch (e) {
      debugPrint("Erro ao abrir câmera para cadastro: $e");
    }
  }

  Future<void> _capturarEVerificarRosto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final XFile foto = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(foto.path);
      
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _exibirSnackBar("Nenhum rosto foi detectado! Olhe firmemente para a câmera.", isErro: true);
        return;
      }

      if (faces.length > 1) {
        _exibirSnackBar("Múltiplos rostos detectados! Certifique-se de estar sozinho.", isErro: true);
        return;
      }

      setState(() {
        _fotoCapturada = foto;
        _rostoDetectado = true;
      });

      _exibirSnackBar("Rosto detectado com sucesso!");
    } catch (e) {
      _exibirSnackBar("Erro ao capturar foto: $e", isErro: true);
    }
  }

  Future<void> _enviarCadastroParaLaravel() async {
    if (_nomeController.text.trim().isEmpty) {
      _exibirSnackBar("Por favor, digite o nome do aluno.", isErro: true);
      return;
    }

    if (_fotoCapturada == null) {
      _exibirSnackBar("Por favor, capture a foto do rosto primeiro.", isErro: true);
      return;
    }

    setState(() => _salvando = true);

    try {
      final dio = Dio();
      
      // SUBSTITUA PELO IP OU URL DA SUA API LARAVEL
      final String urlApi = "http://192.168.1.100:8000/api/alunos/cadastrar-com-foto";

      final formData = FormData.fromMap({
        'nome': _nomeController.text.trim(),
        'foto': await MultipartFile.fromFile(
          _fotoCapturada!.path,
          filename: 'rosto_aluno.jpg',
        ),
      });

      final response = await dio.post(urlApi, data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _exibirSnackBar("Cadastro realizado com sucesso!");
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Erro no cadastro Laravel: $e");
      _exibirSnackBar("Erro ao salvar cadastro no servidor.", isErro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _exibirSnackBar(String msg, {bool isErro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isErro ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SifeTheme.textDark,
      appBar: AppBar(
        title: const Text("CADASTRO DE BIOMETRIA FACIAL"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Campo para digitação do nome do aluno
              TextField(
                controller: _nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Nome do Aluno",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 24),

              // Câmera ou Preview da Foto
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _rostoDetectado ? Colors.green : SifeTheme.primaryRed,
                      width: 4,
                    ),
                  ),
                  child: ClipOval(
                    child: _fotoCapturada != null
                        ? Image.file(File(_fotoCapturada!.path), fit: BoxFit.cover)
                        : (_cameraInicializada && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : const Center(child: CircularProgressIndicator())),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botões de Ação
              if (_fotoCapturada == null)
                ElevatedButton.icon(
                  onPressed: _capturarEVerificarRosto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("TIRAR FOTO E VERIFICAR ROSTO"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: SifeTheme.primaryRed,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _fotoCapturada = null;
                          _rostoDetectado = false;
                        }),
                        child: const Text("TIRAR OUTRA", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _salvando ? null : _enviarCadastroParaLaravel,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: _salvando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text("SALVAR CADASTRO"),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}