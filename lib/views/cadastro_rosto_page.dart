import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../config/face_test_config.dart';
import '../config/theme.dart';
import '../controllers/frequencia_controller.dart';
import '../services/api_service.dart';
import '../services/face_recognition_service.dart';

class CadastroRostoPage extends StatefulWidget {
  const CadastroRostoPage({super.key});

  @override
  State<CadastroRostoPage> createState() => _CadastroRostoPageState();
}

class _CadastroRostoPageState extends State<CadastroRostoPage> {
  // ---------------------------------------------------------------------------
  // CONSTANTES
  // ---------------------------------------------------------------------------

  static const Color _bgTop = Color(0xFF0B1220);
  static const Color _bgBottom = Color(0xFF111A2E);
  static const Color _cardBg = Color(0xFF151F33);
  static const Color _cardBorder = Color(0xFF24324D);
  static const Color _textMuted = Color(0xFF8DA0BC);
  static const Color _success = Color(0xFF22C55E);
  static const Color _error = Color(0xFFDC2626);

  static const double _mobileListHeight = 280;
  static const double _desktopListHeight = 420;
  static const double _desktopBreakpoint = 840;

  // ---------------------------------------------------------------------------
  // CONTROLLERS / SERVICES
  // ---------------------------------------------------------------------------

  CameraController? _cameraController;

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

  // ---------------------------------------------------------------------------
  // ESTADO
  // ---------------------------------------------------------------------------

  bool _cameraInicializada = false;
  bool _inicializandoCamera = false;
  bool _rostoDetectado = false;
  bool _salvando = false;
  bool _carregandoAlunos = false;

  XFile? _fotoCapturada;
  Uint8List? _fotoBytes;

  Map<String, dynamic>? _alunoSelecionado;

  // ---------------------------------------------------------------------------
  // CICLO DE VIDA
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarTela();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _buscaController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // INICIALIZAÇÃO
  // ---------------------------------------------------------------------------

  Future<void> _inicializarTela() async {
    if (!kIsWeb) {
      await _inicializarCamera();
    }

    if (!mounted) return;

    await _carregarAlunos();
  }

  // ---------------------------------------------------------------------------
  // ALUNOS
  // ---------------------------------------------------------------------------

  Future<void> _carregarAlunos() async {
    if (!mounted) return;

    setState(() {
      _carregandoAlunos = true;
    });

    try {
      final controller = context.read<FrequenciaController>();

      _log(
        'CADASTRO DE ROSTO\n'
        'Turma atual: ${controller.turmaSelecionada}\n'
        'Alunos atuais: ${controller.alunos.length}',
      );

      await _garantirTurmaSelecionada(controller);

      final turma = controller.turmaSelecionada;

      if (turma == null || turma <= 0) {
        _log('Nenhuma turma válida foi selecionada.');
        return;
      }

      _log('Buscando alunos da turma $turma');

      await controller.buscarChamada();

      _log('Alunos após busca: ${controller.alunos.length}');
    } catch (e, stackTrace) {
      _logError(
        'Erro ao carregar alunos',
        e,
        stackTrace,
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _carregandoAlunos = false;
      });
    }
  }

  Future<void> _garantirTurmaSelecionada(
    FrequenciaController controller,
  ) async {
    final turma = controller.turmaSelecionada;

    if (turma != null && turma > 0) {
      return;
    }

    _log('Nenhuma turma selecionada. Buscando turmas...');

    await controller.buscarTurmasDoBanco();
  }

  List<Map<String, dynamic>> _obterAlunos(List alunos) {
    final busca = _buscaController.text.trim().toLowerCase();

    final lista = alunos
        .map(_converterAluno)
        .whereType<Map<String, dynamic>>()
        .toList();

    final filtrados = lista.where((aluno) {
      if (busca.isEmpty) {
        return true;
      }

      final nome = _nomeAluno(aluno).toLowerCase();

      return nome.contains(busca);
    }).toList();

    filtrados.sort((a, b) {
      return _nomeAluno(a).compareTo(_nomeAluno(b));
    });

    return filtrados;
  }

  Map<String, dynamic>? _converterAluno(dynamic aluno) {
    if (aluno is Map<String, dynamic>) {
      return aluno;
    }

    if (aluno is Map) {
      return Map<String, dynamic>.from(aluno);
    }

    try {
      final dynamic objeto = aluno;

      return Map<String, dynamic>.from(objeto.toJson());
    } catch (_) {
      return null;
    }
  }

  String _nomeAluno(Map<String, dynamic> aluno) {
    return (
      aluno['nome'] ??
      aluno['nome_aluno'] ??
      'Aluno'
    ).toString();
  }

  int _idAluno(Map<String, dynamic> aluno) {
    return int.tryParse(
          (
            aluno['id_aluno'] ??
            aluno['id'] ??
            ''
          ).toString(),
        ) ??
        0;
  }

  // ---------------------------------------------------------------------------
  // CÂMERA
  // ---------------------------------------------------------------------------

  Future<void> _inicializarCamera() async {
    if (_inicializandoCamera || _cameraInicializada) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _inicializandoCamera = true;
    });

    try {
      _log('Iniciando câmera...');

      await _verificarPermissaoCamera();

      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception(
          'Nenhuma câmera foi encontrada neste dispositivo.',
        );
      }

      final camera = _selecionarCamera(cameras);

      _log(
        'Câmera escolhida: ${camera.name}\n'
        'Direção: ${camera.lensDirection}',
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      if (!controller.value.isInitialized) {
        throw Exception(
          'A câmera foi criada, mas não foi inicializada.',
        );
      }

      _log(
        'Câmera inicializada com sucesso.\n'
        'Resolução: '
        '${controller.value.previewSize?.width} x '
        '${controller.value.previewSize?.height}',
      );

      setState(() {
        _cameraInicializada = true;
      });
    } on CameraException catch (e) {
      _log(
        'CameraException\n'
        'Código: ${e.code}\n'
        'Descrição: ${e.description}',
      );

      if (mounted) {
        _exibirSnackBar(
          'Erro da câmera: ${e.description ?? e.code}',
          isErro: true,
        );
      }
    } catch (e, stackTrace) {
      _logError(
        'Erro ao abrir câmera',
        e,
        stackTrace,
      );

      if (mounted) {
        _exibirSnackBar(
          _mensagemErro(e),
          isErro: true,
        );
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _inicializandoCamera = false;
      });
    }
  }

  Future<void> _verificarPermissaoCamera() async {
    var status = await Permission.camera.status;

    _log('Permissão atual da câmera: $status');

    if (status.isGranted) {
      return;
    }

    status = await Permission.camera.request();

    _log('Permissão após solicitação: $status');

    if (status.isGranted) {
      return;
    }

    if (status.isPermanentlyDenied) {
      throw Exception(
        'A permissão da câmera foi bloqueada. '
        'Abra as configurações do aplicativo e permita o acesso à câmera.',
      );
    }

    throw Exception(
      'Permissão da câmera não concedida.',
    );
  }

  CameraDescription _selecionarCamera(
    List<CameraDescription> cameras,
  ) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        return camera;
      }
    }

    return cameras.first;
  }

  // ---------------------------------------------------------------------------
  // CAPTURA
  // ---------------------------------------------------------------------------

  Future<void> _capturarEVerificarRosto() async {
    if (_alunoSelecionado == null) {
      _exibirSnackBar(
        'Primeiro selecione um aluno.',
        isErro: true,
      );
      return;
    }

    if (FaceTestConfig.ativo) {
      await _carregarFotoDeTeste();

      return;
    }

    if (!_cameraPronta) {
      _exibirSnackBar(
        'A câmera ainda não está pronta.',
        isErro: true,
      );
      return;
    }

    try {
      final foto = await _cameraController!.takePicture();

      _log('Foto capturada: ${foto.path}');

      final faces = await _detectarRostos(foto);

      _log('Rostos detectados: ${faces.length}');

      if (!_validarQuantidadeRostos(faces.length)) {
        return;
      }

      final bytes = await foto.readAsBytes();

      if (!mounted) return;

      setState(() {
        _fotoBytes = bytes;
        _fotoCapturada = foto;
        _rostoDetectado = true;
      });

      _exibirSnackBar(
        'Rosto detectado com sucesso!',
      );
    } catch (e, stackTrace) {
      _logError(
        'Erro ao capturar rosto',
        e,
        stackTrace,
      );

      if (mounted) {
        _exibirSnackBar(
          'Erro ao capturar o rosto.',
          isErro: true,
        );
      }
    }
  }

  Future<void> _carregarFotoDeTeste() async {
    try {
      final data = await rootBundle.load(
        FaceTestConfig.foto,
      );

      final bytes = data.buffer.asUint8List();

      if (!mounted || _alunoSelecionado == null) {
        return;
      }

      setState(() {
        _fotoBytes = bytes;
        _fotoCapturada = XFile.fromData(
          bytes,
          name: 'rosto-teste.png',
          mimeType: 'image/png',
        );
        _rostoDetectado = true;
      });
    } catch (e, stackTrace) {
      _logError(
        'Erro ao carregar foto de teste',
        e,
        stackTrace,
      );

      if (mounted) {
        _exibirSnackBar(
          'Não foi possível carregar a foto de teste.',
          isErro: true,
        );
      }
    }
  }

  Future<List<Face>> _detectarRostos(XFile foto) async {
    final inputImage = InputImage.fromFilePath(
      foto.path,
    );

    return _faceDetector.processImage(
      inputImage,
    );
  }

  bool _validarQuantidadeRostos(int quantidade) {
    if (quantidade == 1) {
      return true;
    }

    if (quantidade == 0) {
      _exibirSnackBar(
        'Nenhum rosto foi detectado. Olhe diretamente para a câmera.',
        isErro: true,
      );

      return false;
    }

    _exibirSnackBar(
      'Foram detectados vários rostos. Apenas uma pessoa deve aparecer.',
      isErro: true,
    );

    return false;
  }

  bool get _cameraPronta {
    final controller = _cameraController;

    return controller != null &&
        _cameraInicializada &&
        controller.value.isInitialized;
  }

  // ---------------------------------------------------------------------------
  // SALVAR CADASTRO
  // ---------------------------------------------------------------------------

  Future<void> _salvarCadastro() async {
    if (_salvando) {
      return;
    }

    if (!_validarCadastro()) {
      return;
    }

    final aluno = _alunoSelecionado!;
    final foto = _fotoCapturada!;

    final idAluno = _idAluno(aluno);
    final nomeAluno = _nomeAluno(aluno);

    if (idAluno <= 0) {
      _exibirSnackBar(
        'Aluno inválido.',
        isErro: true,
      );
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      _log(
        'Salvando biometria facial\n'
        'ID: $idAluno\n'
        'Nome: $nomeAluno\n'
        'Foto: ${foto.path}',
      );

      final imageBytes = await foto.readAsBytes();

      if (imageBytes.isEmpty) {
        throw Exception(
          'A foto capturada está vazia.',
        );
      }

      await _salvarFoto(
        idAluno: idAluno,
        bytes: imageBytes,
        caminhoFoto: foto.path,
      );

      if (!mounted) return;

      await context
          .read<FrequenciaController>()
          .buscarChamada();

      if (!mounted) return;

      _exibirSnackBar(
        FaceTestConfig.ativo
            ? 'Foto de teste associada a $nomeAluno.'
            : 'Rosto de $nomeAluno cadastrado com sucesso!',
      );

      await Future.delayed(
        const Duration(milliseconds: 800),
      );

      if (!mounted) return;

      _limparCadastro();
    } on ApiException catch (e) {
      _log(
        'Erro da API no cadastro facial\n'
        'Contexto: ${e.contexto}\n'
        'Status: ${e.statusCode}\n'
        'Mensagem: ${e.mensagemAmigavel}\n'
        'Detalhes: ${e.detalhesBackend}',
      );

      if (mounted) {
        _exibirSnackBar(
          e.mensagemAmigavel,
          isErro: true,
        );
      }
    } catch (e, stackTrace) {
      _logError(
        'Erro ao salvar rosto',
        e,
        stackTrace,
      );

      if (mounted) {
        _exibirSnackBar(
          _mensagemErro(e),
          isErro: true,
        );
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _salvando = false;
      });
    }
  }

  bool _validarCadastro() {
    if (_alunoSelecionado == null) {
      _exibirSnackBar(
        'Selecione um aluno primeiro.',
        isErro: true,
      );

      return false;
    }

    if (_fotoCapturada == null) {
      _exibirSnackBar(
        'Capture o rosto do aluno primeiro.',
        isErro: true,
      );

      return false;
    }

    return true;
  }

  Future<void> _salvarFoto({
    required int idAluno,
    required Uint8List bytes,
    required String caminhoFoto,
  }) async {
    if (FaceTestConfig.ativo) {
      await _apiService.enviarFotoTeste(
        bytes: bytes,
        idAluno: idAluno,
      );

      return;
    }

    final embedding = await _faceRecognitionService.extrairRosto(
      bytes,
    );

    if (embedding == null || embedding.isEmpty) {
      throw Exception(
        'Não foi possível gerar a biometria. '
        'Tire outra foto de frente.',
      );
    }

    final salvo = await _apiService.cadastrarRosto(
      idAluno: idAluno,
      embedding: embedding,
      caminhoFoto: caminhoFoto,
    );

    if (!salvo) {
      throw Exception(
        'Não foi possível salvar o rosto.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // AÇÕES DO CADASTRO
  // ---------------------------------------------------------------------------

  void _tirarOutraFoto() {
    if (_salvando) {
      return;
    }

    setState(() {
      _fotoCapturada = null;
      _fotoBytes = null;
      _rostoDetectado = false;
    });
  }

  void _limparCadastro() {
    setState(() {
      _alunoSelecionado = null;
      _fotoCapturada = null;
      _fotoBytes = null;
      _rostoDetectado = false;
    });
  }

  void _selecionarAluno(
    Map<String, dynamic> aluno,
  ) {
    if (_salvando || _alunoBloqueado(aluno)) {
      return;
    }

    setState(() {
      _alunoSelecionado = aluno;
      _fotoCapturada = null;
      _fotoBytes = null;
      _rostoDetectado = false;
    });
  }

  bool _alunoBloqueado(
    Map<String, dynamic> aluno,
  ) {
    final temRosto = aluno['tem_rosto'] == true;

    final temRostoTeste =
        FaceTestConfig.ativo &&
        aluno['tem_rosto_teste'] == true;

    return temRosto || temRostoTeste;
  }

  Future<void> _removerTeste(
    Map<String, dynamic> aluno,
  ) async {
    if (_salvando) {
      return;
    }

    final idAluno = _idAluno(aluno);

    if (idAluno <= 0) {
      _exibirSnackBar(
        'Aluno inválido.',
        isErro: true,
      );
      return;
    }

    setState(() {
      _salvando = true;
    });

    try {
      await _apiService.removerFotoTeste(
        idAluno,
      );

      if (!mounted) return;

      await context
          .read<FrequenciaController>()
          .buscarChamada();
    } on ApiException catch (e) {
      if (mounted) {
        _exibirSnackBar(
          e.mensagemAmigavel,
          isErro: true,
        );
      }
    } catch (e, stackTrace) {
      _logError(
        'Erro ao remover foto de teste',
        e,
        stackTrace,
      );

      if (mounted) {
        _exibirSnackBar(
          _mensagemErro(e),
          isErro: true,
        );
      }
    } finally {
      if (!mounted) return;

      setState(() {
        _salvando = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _getIniciais(String nome) {
    final partes = nome
        .trim()
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();

    if (partes.isEmpty) {
      return '?';
    }

    if (partes.length == 1) {
      return partes.first
          .substring(0, 1)
          .toUpperCase();
    }

    return '${partes.first.substring(0, 1)}'
            '${partes.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _mensagemErro(Object erro) {
    return erro
        .toString()
        .replaceFirst('Exception: ', '');
  }

  void _log(String mensagem) {
    debugPrint(
      '========================================\n'
      '$mensagem\n'
      '========================================',
    );
  }

  void _logError(
    String contexto,
    Object erro,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '========================================\n'
      '$contexto\n'
      '$erro\n'
      '$stackTrace\n'
      '========================================',
    );
  }

  // ---------------------------------------------------------------------------
  // SNACKBAR
  // ---------------------------------------------------------------------------

  void _exibirSnackBar(
    String mensagem, {
    bool isErro = false,
  }) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isErro ? _error : _success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMPONENTES VISUAIS
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader({
    required int numero,
    required String titulo,
    required IconData icone,
    bool concluido = false,
  }) {
    final cor = concluido
        ? _success
        : SifeTheme.primaryRed;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: cor.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            concluido
                ? Icons.check_rounded
                : icone,
            color: cor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$numero de 2',
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _cardBorder,
        ),
      ),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // CÂMERA / PREVIEW
  // ---------------------------------------------------------------------------

  Widget _buildCamera() {
    final capturado =
        _fotoCapturada != null &&
        _rostoDetectado;

    final corBorda = capturado
        ? _success
        : SifeTheme.primaryRed;

    final tamanho =
        MediaQuery.of(context).size.width >= _desktopBreakpoint
            ? 320.0
            : 250.0;

    const espacoAnel = 12.0;

    final diametroInterno =
        tamanho - espacoAnel * 2;

    final conteudo = _buildConteudoCamera();

    return Center(
      child: SizedBox(
        width: tamanho,
        height: tamanho,
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
            Positioned.fill(
              child: CustomPaint(
                painter: _AnelRostoPainter(
                  color: corBorda,
                  completo: capturado,
                ),
              ),
            ),
            if (capturado)
              _buildIndicadorSucesso(),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudoCamera() {
    if (FaceTestConfig.ativo) {
      return Image.asset(
        FaceTestConfig.foto,
        fit: BoxFit.cover,
      );
    }

    if (_inicializandoCamera) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.4,
        ),
      );
    }

    if (!_cameraPronta) {
      return _buildCameraIndisponivel();
    }

    if (_fotoCapturada != null &&
        _fotoBytes != null) {
      return Image.memory(
        _fotoBytes!,
        fit: BoxFit.cover,
      );
    }

    final previewSize =
        _cameraController!.value.previewSize;

    if (previewSize == null) {
      return const Center(
        child: Icon(
          Icons.videocam_off_rounded,
          color: Colors.white38,
          size: 38,
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(
          _cameraController!,
        ),
      ),
    );
  }

  Widget _buildCameraIndisponivel() {
    return Padding(
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
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _inicializarCamera,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 16,
              color: Colors.white70,
            ),
            label: const Text(
              'Tentar novamente',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicadorSucesso() {
    return Positioned(
      right: 18,
      bottom: 18,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _success,
          shape: BoxShape.circle,
          border: Border.all(
            color: _cardBg,
            width: 3,
          ),
        ),
        child: const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ETAPAS
  // ---------------------------------------------------------------------------

  Widget _buildPasso({
    required int numero,
    required String rotulo,
    required bool ativo,
    required bool concluido,
  }) {
    final Color corFundo;
    final Color corBorda;

    if (concluido) {
      corFundo = _success;
      corBorda = _success;
    } else if (ativo) {
      corFundo = SifeTheme.primaryRed
          .withOpacity(0.16);
      corBorda = SifeTheme.primaryRed;
    } else {
      corFundo = Colors.transparent;
      corBorda = _cardBorder;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(
            milliseconds: 220,
          ),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: corFundo,
            shape: BoxShape.circle,
            border: Border.all(
              color: corBorda,
              width: 1.5,
            ),
          ),
          child: concluido
              ? const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                )
              : Text(
                  '$numero',
                  style: TextStyle(
                    color: ativo
                        ? Colors.white
                        : _textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          rotulo,
          style: TextStyle(
            color: ativo || concluido
                ? Colors.white
                : _textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressoEtapas({
    required bool etapaAlunoConcluida,
    required bool etapaRostoConcluida,
  }) {
    return Row(
      children: [
        _buildPasso(
          numero: 1,
          rotulo: 'Aluno',
          ativo: true,
          concluido: etapaAlunoConcluida,
        ),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 220,
            ),
            height: 2,
            margin: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(2),
              color: etapaAlunoConcluida
                  ? _success
                  : _cardBorder,
            ),
          ),
        ),
        _buildPasso(
          numero: 2,
          rotulo: 'Rosto',
          ativo: etapaAlunoConcluida,
          concluido: etapaRostoConcluida,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ITEM DO ALUNO
  // ---------------------------------------------------------------------------

  Widget _buildItemAluno(
    Map<String, dynamic> aluno,
  ) {
    final nome = _nomeAluno(aluno);
    final id = _idAluno(aluno);

    final idSelecionado =
        _alunoSelecionado == null
            ? 0
            : _idAluno(_alunoSelecionado!);

    final selecionado =
        idSelecionado == id && id > 0;

    final temRosto =
        aluno['tem_rosto'] == true;

    final temRostoTeste =
        FaceTestConfig.ativo &&
        aluno['tem_rosto_teste'] == true;

    final bloqueado =
        _salvando ||
        temRosto ||
        temRostoTeste;

    return InkWell(
      onTap: bloqueado
          ? null
          : () => _selecionarAluno(aluno),
      borderRadius:
          BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 150,
        ),
        padding:
            const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: selecionado
              ? SifeTheme.primaryRed
                  .withOpacity(0.12)
              : Colors.white.withOpacity(0.03),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: selecionado
                ? SifeTheme.primaryRed
                    .withOpacity(0.55)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: selecionado
                  ? SifeTheme.primaryRed
                  : Colors.white
                      .withOpacity(0.09),
              child: Text(
                _getIniciais(nome),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nome,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      bloqueado && !selecionado
                          ? Colors.white
                              .withOpacity(0.6)
                          : Colors.white,
                  fontSize: 14.5,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildTrailingAluno(
              temRosto: temRosto,
              temRostoTeste: temRostoTeste,
              selecionado: selecionado,
              aluno: aluno,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingAluno({
    required bool temRosto,
    required bool temRostoTeste,
    required bool selecionado,
    required Map<String, dynamic> aluno,
  }) {
    if (temRosto) {
      return Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color:
              _success.withOpacity(0.12),
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: _success,
              size: 14,
            ),
            SizedBox(width: 5),
            Text(
              'Cadastrado',
              style: TextStyle(
                color: _success,
                fontSize: 11.5,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (temRostoTeste) {
      return TextButton(
        onPressed: _salvando
            ? null
            : () => _removerTeste(aluno),
        child: const Text(
          'Remover teste',
        ),
      );
    }

    if (selecionado) {
      return const Icon(
        Icons.check_circle_rounded,
        color: _success,
        size: 22,
      );
    }

    return Icon(
      Icons.chevron_right_rounded,
      color: Colors.white
          .withOpacity(0.25),
      size: 22,
    );
  }

  // ---------------------------------------------------------------------------
  // AÇÕES
  // ---------------------------------------------------------------------------

  Widget _buildAcoes() {
    if (_fotoCapturada == null) {
      return _buildBotaoPrimario(
        label: FaceTestConfig.ativo
            ? 'Usar foto de teste'
            : 'Capturar rosto',
        icone: Icons.camera_alt_rounded,
        habilitado:
            _alunoSelecionado != null &&
            (_cameraInicializada ||
                FaceTestConfig.ativo),
        onPressed:
            _capturarEVerificarRosto,
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _salvando
                  ? null
                  : _tirarOutraFoto,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),
              label: const Text(
                'Refazer',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.white,
                side:
                    const BorderSide(
                  color: _cardBorder,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildBotaoPrimario(
            label: _salvando
                ? 'Salvando...'
                : 'Salvar rosto',
            icone: Icons.save_rounded,
            habilitado: !_salvando,
            carregando: _salvando,
            cor: _success,
            onPressed: _salvarCadastro,
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoPrimario({
    required String label,
    required IconData icone,
    required bool habilitado,
    required VoidCallback onPressed,
    bool carregando = false,
    Color? cor,
  }) {
    final corBotao =
        cor ?? SifeTheme.primaryRed;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed:
            habilitado ? onPressed : null,
        icon: carregando
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Icon(
                icone,
                size: 20,
              ),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: corBotao,
          disabledBackgroundColor:
              Colors.white
                  .withOpacity(0.06),
          disabledForegroundColor:
              Colors.white38,
          foregroundColor:
              Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller =
        context.watch<FrequenciaController>();

    final alunos =
        _obterAlunos(controller.alunos);

    final etapaAlunoConcluida =
        _alunoSelecionado != null;

    final etapaRostoConcluida =
        _fotoCapturada != null &&
        _rostoDetectado;

    final comRosto = alunos
        .where(
          (aluno) =>
              aluno['tem_rosto'] == true ||
              (
                FaceTestConfig.ativo &&
                aluno['tem_rosto_teste'] == true
              ),
        )
        .length;

    final tecladoAberto =
        MediaQuery.of(context)
                .viewInsets
                .bottom >
            0;

    final largo =
        MediaQuery.of(context).size.width >=
            _desktopBreakpoint;

    final alturaLista = largo
        ? _desktopListHeight
        : _mobileListHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _bgTop,
      appBar: _buildAppBar(),
      bottomNavigationBar:
          tecladoAberto
              ? null
              : _buildBottomBar(largo),
      body: _buildBody(
        alunos: alunos,
        comRosto: comRosto,
        alturaLista: alturaLista,
        largo: largo,
        etapaAlunoConcluida:
            etapaAlunoConcluida,
        etapaRostoConcluida:
            etapaRostoConcluida,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }

  Widget _buildBottomBar(bool largo) {
    return Container(
      decoration: const BoxDecoration(
        color: _bgBottom,
        border: Border(
          top: BorderSide(
            color: _cardBorder,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12,
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 200,
          ),
          child: KeyedSubtree(
            key: ValueKey(
              _fotoCapturada == null,
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      largo ? 520 : 640,
                ),
                child: _buildAcoes(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<Map<String, dynamic>> alunos,
    required int comRosto,
    required double alturaLista,
    required bool largo,
    required bool etapaAlunoConcluida,
    required bool etapaRostoConcluida,
  }) {
    return Container(
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
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context)
                        .padding
                        .top >
                    0
                ? 8
                : 20,
            20,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(
                maxWidth:
                    largo ? 1040 : 640,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  _buildCabecalho(
                    etapaAlunoConcluida:
                        etapaAlunoConcluida,
                    etapaRostoConcluida:
                        etapaRostoConcluida,
                  ),
                  const SizedBox(height: 22),
                  if (largo)
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child:
                              _buildCardAlunos(
                            alunos: alunos,
                            comRosto: comRosto,
                            alturaLista:
                                alturaLista,
                          ),
                        ),
                        const SizedBox(
                          width: 20,
                        ),
                        Expanded(
                          child:
                              _buildCardCamera(
                            etapaRostoConcluida:
                                etapaRostoConcluida,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildCardAlunos(
                      alunos: alunos,
                      comRosto: comRosto,
                      alturaLista:
                          alturaLista,
                    ),
                    const SizedBox(
                      height: 16,
                    ),
                    _buildCardCamera(
                      etapaRostoConcluida:
                          etapaRostoConcluida,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCabecalho({
    required bool etapaAlunoConcluida,
    required bool etapaRostoConcluida,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Registrar rosto do aluno',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          FaceTestConfig.ativo
              ? 'Simulação web: associe a foto de teste a um aluno sem cadastro. A foto testa o fluxo da chamada; o rosto real será cadastrado no APK.'
              : 'Cadastre apenas os alunos sem rosto. Quem já possui cadastro pode usar o totem.',
          style: const TextStyle(
            color: _textMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        _buildProgressoEtapas(
          etapaAlunoConcluida:
              etapaAlunoConcluida,
          etapaRostoConcluida:
              etapaRostoConcluida,
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildCardAlunos({
    required List<Map<String, dynamic>> alunos,
    required int comRosto,
    required double alturaLista,
  }) {
    return _buildCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            numero: 1,
            titulo: 'Selecione o aluno',
            icone:
                Icons.person_search_rounded,
            concluido:
                _alunoSelecionado != null,
          ),
          const SizedBox(height: 16),
          _buildCampoBusca(),
          if (!_carregandoAlunos &&
              alunos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '$comRosto de ${alunos.length} com rosto cadastrado',
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildListaAlunos(
            alunos: alunos,
            alturaLista: alturaLista,
          ),
        ],
      ),
    );
  }

  Widget _buildCampoBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar por nome...',
        hintStyle: const TextStyle(
          color: Colors.white38,
          fontSize: 14.5,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.white38,
          size: 20,
        ),
        suffixIcon:
            _buscaController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                    onPressed: () {
                      _buscaController
                          .clear();
                      setState(() {});
                    },
                  )
                : null,
        filled: true,
        fillColor:
            Colors.black.withOpacity(0.22),
        contentPadding:
            const EdgeInsets.symmetric(
          vertical: 14,
        ),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(
          Color: SifeTheme.primaryRed,
          width: 1.4,
        ),
      ),
    );
  }

  OutlineInputBorder _inputBorder({
    Color = _cardBorder,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Color,
        width: width,
      ),
    );
  }

  Widget _buildListaAlunos({
    required List<Map<String, dynamic>> alunos,
    required double alturaLista,
  }) {
    if (_carregandoAlunos) {
      return const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 28,
        ),
        child: Center(
          child:
              CircularProgressIndicator(
            color: Colors.white70,
            strokeWidth: 2.2,
          ),
        ),
      );
    }

    if (alunos.isEmpty) {
      return _buildListaVazia();
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: alturaLista,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: alunos.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: 6),
        itemBuilder: (_, index) {
          return _buildItemAluno(
            alunos[index],
          );
        },
      ),
    );
  }

  Widget _buildListaVazia() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 20,
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withOpacity(0.06),
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
                fontWeight:
                    FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed:
                  _carregarAlunos,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label: const Text(
                'Carregar alunos',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.white,
                side:
                    const BorderSide(
                  color: _cardBorder,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardCamera({
    required bool etapaRostoConcluida,
  }) {
    return _buildCard(
      child: Column(
        children: [
          _buildSectionHeader(
            numero: 2,
            titulo: FaceTestConfig.ativo
                ? 'Foto de teste — simulação web'
                : 'Capture o rosto',
            icone: Icons
                .face_retouching_natural_rounded,
            concluido:
                etapaRostoConcluida,
          ),
          const SizedBox(height: 22),
          _buildCamera(),
          const SizedBox(height: 20),
          _buildStatusRosto(
            concluido:
                etapaRostoConcluida,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRosto({
    required bool concluido,
  }) {
    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 200,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: concluido
            ? _success.withOpacity(0.12)
            : Colors.white
                .withOpacity(0.05),
        borderRadius:
            BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            concluido
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 15,
            color: concluido
                ? _success
                : Colors.white60,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              concluido
                  ? (
                      FaceTestConfig.ativo
                          ? 'Foto de teste selecionada'
                          : 'Rosto detectado com sucesso'
                    )
                  : (
                      FaceTestConfig.ativo
                          ? 'Associe a foto a um único aluno'
                          : 'Posicione o rosto dentro do círculo'
                    ),
              style: TextStyle(
                color: concluido
                    ? _success
                    : Colors.white60,
                fontWeight:
                    FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ANEL DE ENQUADRAMENTO DO ROSTO
// =============================================================================

class _AnelRostoPainter extends CustomPainter {
  final Color color;
  final bool completo;

  const _AnelRostoPainter({
    required this.color,
    required this.completo,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final centro =
        size.center(Offset.zero);

    final raio =
        size.width / 2 - 4;

    final area = Rect.fromCircle(
      center: centro,
      radius: raio,
    );

    canvas.drawCircle(
      centro,
      raio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color =
            color.withOpacity(0.22),
    );

    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = color;

    if (completo) {
      canvas.drawCircle(
        centro,
        raio,
        traco,
      );
      return;
    }

    const pi = 3.14159265;
    const varredura = pi / 3;

    for (var i = 0; i < 4; i++) {
      final centroDoArco =
          -pi / 4 + i * (pi / 2);

      canvas.drawArc(
        area,
        centroDoArco -
            varredura / 2,
        varredura,
        false,
        traco,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _AnelRostoPainter antigo,
  ) {
    return antigo.color != color ||
        antigo.completo != completo;
  }
}
