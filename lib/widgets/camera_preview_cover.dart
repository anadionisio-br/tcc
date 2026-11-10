import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Exibe o [CameraPreview] preenchendo todo o espaço disponível
/// (como um BoxFit.cover), sem distorcer a imagem.
///
/// A proporção usada aqui replica a lógica interna do [CameraPreview]
/// (que inverte largura/altura somente quando a orientação aplicável
/// é retrato). Se a caixa externa tiver uma proporção diferente da que
/// o CameraPreview espera, ele é forçado a esticar.
class CameraPreviewCover extends StatelessWidget {
  const CameraPreviewCover({
    super.key,
    required this.controller,
  });

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final previewSize = value.previewSize;

        if (!value.isInitialized || previewSize == null) {
          return CameraPreview(controller);
        }

        final orientacao = value.isRecordingVideo
            ? value.recordingOrientation
            : (value.previewPauseOrientation ??
                value.lockedCaptureOrientation ??
                value.deviceOrientation);

        final paisagem = orientacao == DeviceOrientation.landscapeLeft ||
            orientacao == DeviceOrientation.landscapeRight;

        // previewSize vem como largura/altura do sensor; em paisagem a
        // imagem é mais larga que alta, em retrato o contrário.
        final largura = paisagem
            ? previewSize.width
            : previewSize.height;
        final altura = paisagem
            ? previewSize.height
            : previewSize.width;

        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: largura,
              height: altura,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}
