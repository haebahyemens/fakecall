import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

class FileTransferClient {
  final String serverIp;
  final int serverPort;
  final String password;
  String? _authToken;
  final Function(double)? onProgress;
  
  FileTransferClient({
    required this.serverIp,
    required this.serverPort,
    required this.password,
    this.onProgress,
  });

  String get baseUrl => 'http://$serverIp:$serverPort';

  Future<bool> authenticate() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _authToken = data['token'];
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }

  Future<bool> uploadFile(File file) async {
    if (_authToken == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final fileBytes = await file.readAsBytes();
      final fileName = path.basename(file.path);
      
      final boundary = _generateBoundary();
      final multipartData = _createMultipartData(fileName, fileBytes, boundary);
      
      final request = http.Request('POST', Uri.parse('$baseUrl/upload'));
      request.headers.addAll({
        'Content-Type': 'multipart/form-data; boundary=$boundary',
        'Authorization': 'Bearer $_authToken',
      });
      
      request.bodyBytes = multipartData;
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        print('Upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  Future<bool> uploadFileWithProgress(File file) async {
    if (_authToken == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final fileBytes = await file.readAsBytes();
      final fileName = path.basename(file.path);
      final fileSize = fileBytes.length;
      
      final boundary = _generateBoundary();
      final multipartData = _createMultipartData(fileName, fileBytes, boundary);
      
      final uri = Uri.parse('$baseUrl/upload');
      final request = http.StreamedRequest('POST', uri);
      request.headers.addAll({
        'Content-Type': 'multipart/form-data; boundary=$boundary',
        'Authorization': 'Bearer $_authToken',
        'Content-Length': multipartData.length.toString(),
      });
      
      // Send data in chunks to track progress
      final chunkSize = 8192; // 8KB chunks
      int bytesSent = 0;
      
      for (int i = 0; i < multipartData.length; i += chunkSize) {
        final end = (i + chunkSize < multipartData.length) ? i + chunkSize : multipartData.length;
        final chunk = multipartData.sublist(i, end);
        request.sink.add(chunk);
        
        bytesSent += chunk.length;
        onProgress?.call(bytesSent / multipartData.length);
      }
      
      await request.sink.close();
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        print('Upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Upload error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFileList() async {
    if (_authToken == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/files'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['files']);
      } else {
        print('Failed to get file list: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting file list: $e');
      return [];
    }
  }

  Future<bool> downloadFile(String filename, String savePath) async {
    if (_authToken == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/download/$filename'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        print('Download failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Download error: $e');
      return false;
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/files'),
        headers: _authToken != null ? {'Authorization': 'Bearer $_authToken'} : {},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200 || response.statusCode == 401 || response.statusCode == 403;
    } catch (e) {
      return false;
    }
  }

  String _generateBoundary() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return '----formdata-flutter-$random';
  }

  Uint8List _createMultipartData(String filename, Uint8List fileBytes, String boundary) {
    final boundaryBytes = utf8.encode('--$boundary\r\n');
    final headerBytes = utf8.encode(
      'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
      'Content-Type: application/octet-stream\r\n\r\n'
    );
    final endBoundaryBytes = utf8.encode('\r\n--$boundary--\r\n');
    
    final totalLength = boundaryBytes.length + headerBytes.length + fileBytes.length + endBoundaryBytes.length;
    final result = Uint8List(totalLength);
    
    int offset = 0;
    result.setRange(offset, offset + boundaryBytes.length, boundaryBytes);
    offset += boundaryBytes.length;
    
    result.setRange(offset, offset + headerBytes.length, headerBytes);
    offset += headerBytes.length;
    
    result.setRange(offset, offset + fileBytes.length, fileBytes);
    offset += fileBytes.length;
    
    result.setRange(offset, offset + endBoundaryBytes.length, endBoundaryBytes);
    
    return result;
  }

  void clearAuth() {
    _authToken = null;
  }
}