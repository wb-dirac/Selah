import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum SherpaModelKind { tts, stt }

class SherpaModelFile {
  const SherpaModelFile({required this.name, required this.url});

  final String name;
  final String url;
}

class SherpaOnnxModelDownloadService {
  SherpaOnnxModelDownloadService({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const List<SherpaModelFile> _ttsFiles = <SherpaModelFile>[
    SherpaModelFile(
      name: 'model.onnx',
      url:
          'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/LICENSE',
    ),
    SherpaModelFile(
      name: 'tokens.txt',
      url:
          'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/LICENSE',
    ),
  ];

  static const List<SherpaModelFile> _sttFiles = <SherpaModelFile>[
    SherpaModelFile(
      name: 'encoder.onnx',
      url:
          'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/LICENSE',
    ),
    SherpaModelFile(
      name: 'decoder.onnx',
      url:
          'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/LICENSE',
    ),
    SherpaModelFile(
      name: 'joiner.onnx',
      url:
          'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/LICENSE',
    ),
    SherpaModelFile(
      name: 'tokens.txt',
      url:
          'https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/LICENSE',
    ),
  ];

  Future<Directory> getModelDirectory(SherpaModelKind kind) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(root.path, 'sherpa_onnx', kind == SherpaModelKind.tts ? 'tts' : 'stt'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isModelReady(SherpaModelKind kind) async {
    final dir = await getModelDirectory(kind);
    final files = kind == SherpaModelKind.tts ? _ttsFiles : _sttFiles;
    for (final file in files) {
      final f = File(p.join(dir.path, file.name));
      if (!await f.exists()) {
        return false;
      }
    }
    return true;
  }

  Future<void> downloadModel(SherpaModelKind kind) async {
    final dir = await getModelDirectory(kind);
    final files = kind == SherpaModelKind.tts ? _ttsFiles : _sttFiles;
    final client = _client ?? http.Client();

    try {
      for (final file in files) {
        final uri = Uri.parse(file.url);
        if (uri.scheme != 'https') {
          throw StateError('Sherpa model URL must be HTTPS: ${file.url}');
        }
        final response = await client.get(uri);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            'Failed to download ${file.name}: HTTP ${response.statusCode}',
          );
        }
        final outFile = File(p.join(dir.path, file.name));
        await outFile.writeAsBytes(response.bodyBytes, flush: true);
      }
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }
}

final sherpaOnnxModelDownloadServiceProvider =
    Provider<SherpaOnnxModelDownloadService>((ref) {
      return SherpaOnnxModelDownloadService();
    });
