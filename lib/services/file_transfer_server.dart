import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileTransferServer {
  HttpServer? _server;
  final String password;
  final int port;
  final Function(String)? onFileReceived;
  final Function(double)? onProgress;
  
  FileTransferServer({
    required this.password,
    required this.port,
    this.onFileReceived,
    this.onProgress,
  });

  String get _hashedPassword => sha256.convert(utf8.encode(password)).toString();

  Future<void> start() async {
    final router = Router();

    // Authentication endpoint
    router.post('/auth', _handleAuth);
    
    // File upload endpoint
    router.post('/upload', _handleFileUpload);
    
    // File list endpoint
    router.get('/files', _handleFileList);
    
    // Download endpoint
    router.get('/download/<filename>', _handleFileDownload);

    // CORS headers
    final handler = Pipeline()
        .addMiddleware(_corsHeaders())
        .addHandler(router);

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Server started on port $port');
      
      await for (HttpRequest request in _server!) {
        handler(Request.fromHttpRequest(request))
            .then((response) => _writeResponse(request.response, response));
      }
    } catch (e) {
      print('Error starting server: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    print('Server stopped');
  }

  Middleware _corsHeaders() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
        });
      };
    };
  }

  Future<Response> _handleAuth(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final clientPassword = data['password'] as String?;
      
      if (clientPassword == null) {
        return Response.badRequest(body: 'Password required');
      }
      
      final clientHashedPassword = sha256.convert(utf8.encode(clientPassword)).toString();
      
      if (clientHashedPassword == _hashedPassword) {
        return Response.ok(jsonEncode({'success': true, 'token': _generateToken()}));
      } else {
        return Response.forbidden(jsonEncode({'success': false, 'message': 'Invalid password'}));
      }
    } catch (e) {
      return Response.internalServerError(body: 'Authentication error: $e');
    }
  }

  Future<Response> _handleFileUpload(Request request) async {
    try {
      if (!_isAuthenticated(request)) {
        return Response.forbidden(jsonEncode({'error': 'Unauthorized'}));
      }

      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.startsWith('multipart/form-data')) {
        return Response.badRequest(body: 'Invalid content type');
      }

      final boundary = _extractBoundary(contentType);
      if (boundary == null) {
        return Response.badRequest(body: 'Invalid boundary');
      }

      final bytes = await request.read().expand((chunk) => chunk).toList();
      final fileData = _parseMultipartData(Uint8List.fromList(bytes), boundary);
      
      if (fileData == null) {
        return Response.badRequest(body: 'No file data found');
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, 'received_files', fileData['filename']);
      
      // Create directory if it doesn't exist
      await Directory(path.dirname(filePath)).create(recursive: true);
      
      final file = File(filePath);
      await file.writeAsBytes(fileData['data']);
      
      onFileReceived?.call(fileData['filename']);
      
      return Response.ok(jsonEncode({
        'success': true,
        'filename': fileData['filename'],
        'size': fileData['data'].length,
      }));
    } catch (e) {
      return Response.internalServerError(body: 'Upload error: $e');
    }
  }

  Future<Response> _handleFileList(Request request) async {
    try {
      if (!_isAuthenticated(request)) {
        return Response.forbidden(jsonEncode({'error': 'Unauthorized'}));
      }

      final directory = await getApplicationDocumentsDirectory();
      final receivedDir = Directory(path.join(directory.path, 'received_files'));
      
      if (!await receivedDir.exists()) {
        return Response.ok(jsonEncode({'files': []}));
      }

      final files = await receivedDir.list().where((entity) => entity is File).map((file) {
        final fileName = path.basename(file.path);
        final stat = (file as File).statSync();
        return {
          'name': fileName,
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
        };
      }).toList();

      return Response.ok(jsonEncode({'files': files}));
    } catch (e) {
      return Response.internalServerError(body: 'File list error: $e');
    }
  }

  Future<Response> _handleFileDownload(Request request, String filename) async {
    try {
      if (!_isAuthenticated(request)) {
        return Response.forbidden(jsonEncode({'error': 'Unauthorized'}));
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, 'received_files', filename);
      final file = File(filePath);
      
      if (!await file.exists()) {
        return Response.notFound('File not found');
      }

      final bytes = await file.readAsBytes();
      return Response.ok(
        bytes,
        headers: {
          'content-type': 'application/octet-stream',
          'content-disposition': 'attachment; filename="$filename"',
        },
      );
    } catch (e) {
      return Response.internalServerError(body: 'Download error: $e');
    }
  }

  bool _isAuthenticated(Request request) {
    final auth = request.headers['authorization'];
    if (auth == null) return false;
    
    final token = auth.replaceFirst('Bearer ', '');
    return token == _generateToken();
  }

  String _generateToken() {
    return sha256.convert(utf8.encode('$password:${DateTime.now().day}')).toString();
  }

  String? _extractBoundary(String contentType) {
    final boundaryMatch = RegExp(r'boundary=(.+)').firstMatch(contentType);
    return boundaryMatch?.group(1);
  }

  Map<String, dynamic>? _parseMultipartData(Uint8List data, String boundary) {
    final boundaryBytes = utf8.encode('--$boundary');
    final endBoundaryBytes = utf8.encode('--$boundary--');
    
    int start = 0;
    while (start < data.length) {
      final boundaryIndex = _findBytes(data, boundaryBytes, start);
      if (boundaryIndex == -1) break;
      
      start = boundaryIndex + boundaryBytes.length;
      if (start >= data.length) break;
      
      // Skip CRLF after boundary
      if (start + 1 < data.length && data[start] == 13 && data[start + 1] == 10) {
        start += 2;
      }
      
      // Find next boundary or end boundary
      final nextBoundaryIndex = _findBytes(data, boundaryBytes, start);
      final endBoundaryIndex = _findBytes(data, endBoundaryBytes, start);
      
      int partEnd;
      if (nextBoundaryIndex != -1 && (endBoundaryIndex == -1 || nextBoundaryIndex < endBoundaryIndex)) {
        partEnd = nextBoundaryIndex - 2; // Remove CRLF before boundary
      } else if (endBoundaryIndex != -1) {
        partEnd = endBoundaryIndex - 2;
      } else {
        break;
      }
      
      final partData = data.sublist(start, partEnd);
      final result = _parseFormDataPart(partData);
      if (result != null) {
        return result;
      }
      
      start = partEnd + 2;
    }
    
    return null;
  }

  Map<String, dynamic>? _parseFormDataPart(Uint8List partData) {
    // Find the double CRLF that separates headers from body
    final doubleCRLF = utf8.encode('\r\n\r\n');
    final headerEndIndex = _findBytes(partData, doubleCRLF, 0);
    
    if (headerEndIndex == -1) return null;
    
    final headerBytes = partData.sublist(0, headerEndIndex);
    final bodyBytes = partData.sublist(headerEndIndex + doubleCRLF.length);
    
    final headerString = utf8.decode(headerBytes);
    final filenameMatch = RegExp(r'filename="([^"]*)"').firstMatch(headerString);
    
    if (filenameMatch != null) {
      return {
        'filename': filenameMatch.group(1),
        'data': bodyBytes,
      };
    }
    
    return null;
  }

  int _findBytes(Uint8List data, List<int> pattern, int start) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  void _writeResponse(HttpResponse httpResponse, Response response) {
    httpResponse.statusCode = response.statusCode;
    response.headers.forEach((key, value) {
      httpResponse.headers.set(key, value);
    });
    
    if (response.body is String) {
      httpResponse.write(response.body);
    } else if (response.body is List<int>) {
      httpResponse.add(response.body as List<int>);
    }
    
    httpResponse.close();
  }
}