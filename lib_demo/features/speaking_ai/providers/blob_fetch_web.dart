import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List> fetchBlobBytes(String url) async {
  final request = await html.HttpRequest.request(
    url,
    responseType: 'arraybuffer',
  );
  final buffer = request.response as ByteBuffer;
  return buffer.asUint8List();
}
