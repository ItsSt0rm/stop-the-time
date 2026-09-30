import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'support/sha256.dart';

/// `flutter test` se ejecuta desde la raíz del proyecto.
const _path = 'assets/audio/anchor.wav';
const _expectedSha256 =
    '8d3f63cdf38458fe38ff514dcc2241a3db0fb1e7fbc3bb8bf434fe2bf32c35a2';
const _expectedSize = 352844;

String _tag(Uint8List b, int offset) =>
    ascii.decode(b.sublist(offset, offset + 4));

void main() {
  final file = File(_path);

  test('el asset existe', () {
    expect(file.existsSync(), isTrue, reason: '$_path no existe');
  });

  test('el helper SHA-256 da los vectores conocidos', () {
    expect(
      sha256Hex(const []),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(ascii.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('tamaño y sha256 coinciden con el generado por el script', () {
    final bytes = file.readAsBytesSync();
    expect(bytes.length, _expectedSize);
    expect(sha256Hex(bytes), _expectedSha256);
  });

  test('WAV PCM 16 bit mono 44.1 kHz de ~4 s (cabe en la entrada)', () {
    final b = file.readAsBytesSync();
    final data = ByteData.sublistView(b);
    expect(_tag(b, 0), 'RIFF');
    expect(data.getUint32(4, Endian.little), b.length - 8);
    expect(_tag(b, 8), 'WAVE');

    // Recorre los chunks: no se asume que 'data' vaya justo tras 'fmt '.
    int? format, channels, sampleRate, byteRate, blockAlign, bits, dataSize;
    var offset = 12;
    while (offset + 8 <= b.length) {
      final id = _tag(b, offset);
      final size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'fmt ') {
        format = data.getUint16(body, Endian.little);
        channels = data.getUint16(body + 2, Endian.little);
        sampleRate = data.getUint32(body + 4, Endian.little);
        byteRate = data.getUint32(body + 8, Endian.little);
        blockAlign = data.getUint16(body + 12, Endian.little);
        bits = data.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        dataSize = size;
      }
      offset = body + size + (size.isOdd ? 1 : 0);
    }

    expect(format, 1, reason: 'PCM');
    expect(channels, 1, reason: 'mono');
    expect(sampleRate, 44100);
    expect(bits, 16);
    expect(blockAlign, 2);
    expect(byteRate, 44100 * 2);
    expect(dataSize, isNotNull);

    final seconds = dataSize! / byteRate!;
    expect(seconds, closeTo(4, 0.05));
    expect(seconds, lessThan(5));
  });
}
