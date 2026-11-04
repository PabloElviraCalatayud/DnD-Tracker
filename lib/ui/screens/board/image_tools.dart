import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as img;

import '../../../core/i18n.dart';

/// Imagen ya preparada para guardarla y enviarla a los jugadores.
class PreparedImage {
  const PreparedImage(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Abre el selector de archivos del sistema y devuelve los bytes de una imagen.
Future<Uint8List?> pickImageFile() async {
  final group = XTypeGroup(
    label: tr('Imágenes'),
    extensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
    mimeTypes: const ['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/bmp'],
    uniformTypeIdentifiers: const ['public.image'],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return null;
  return file.readAsBytes();
}

/// Limita el mapa a 4096 px por lado (suficiente para ampliarlo mucho sin que
/// se vea borroso) y lo guarda como JPEG de alta calidad, que pesa bastante
/// menos que un PNG y se envía rápido a los jugadores, incluso por el relay.
Future<PreparedImage?> prepareMapImage(Uint8List bytes) => Isolate.run(() {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = decoded;
  const maxSide = 4096;
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.cubic)
        : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.cubic);
  }
  final jpg = img.encodeJpg(image, quality: 92);
  return PreparedImage(Uint8List.fromList(jpg), image.width, image.height);
});

/// Recorta al centro en cuadrado, reduce a 512 px y guarda como PNG
/// (conserva la transparencia de las fichas).
Future<PreparedImage?> prepareTokenImage(Uint8List bytes) => Isolate.run(() {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = side > 512
      ? img.copyResize(square, width: 512, height: 512, interpolation: img.Interpolation.cubic)
      : square;
  final png = img.encodePng(small, level: 6);
  return PreparedImage(Uint8List.fromList(png), small.width, small.height);
});
