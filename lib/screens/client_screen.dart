import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/file_transfer_client.dart';
import '../services/network_service.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _passwordController = TextEditingController();
  
  FileTransferClient? _client;
  bool _isConnected = false;
  bool _isLoading = false;
  List<File> _selectedFiles = [];
  double _uploadProgress = 0.0;
  String? _currentUploadFile;
  List<Map<String, dynamic>> _serverFiles = [];

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_ipController.text.isEmpty || 
        _portController.text.isEmpty || 
        _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all connection details', isError: true);
      return;
    }

    if (!NetworkService.isValidIP(_ipController.text)) {
      _showSnackBar('Please enter a valid IP address', isError: true);
      return;
    }

    if (!NetworkService.isValidPort(_portController.text)) {
      _showSnackBar('Please enter a valid port number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _client = FileTransferClient(
        serverIp: _ipController.text,
        serverPort: int.parse(_portController.text),
        password: _passwordController.text,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      // Test connection first
      if (!await _client!.testConnection()) {
        throw Exception('Cannot reach server');
      }

      // Authenticate
      final authenticated = await _client!.authenticate();
      if (!authenticated) {
        throw Exception('Authentication failed. Check your password.');
      }

      setState(() {
        _isConnected = true;
        _isLoading = false;
      });

      _showSnackBar('Connected successfully!');
      _loadServerFiles();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _client = null;
      });
      _showSnackBar('Connection failed: $e', isError: true);
    }
  }

  Future<void> _disconnect() async {
    _client?.clearAuth();
    setState(() {
      _client = null;
      _isConnected = false;
      _selectedFiles.clear();
      _serverFiles.clear();
      _uploadProgress = 0.0;
      _currentUploadFile = null;
    });
    _showSnackBar('Disconnected');
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.paths
              .where((path) => path != null)
              .map((path) => File(path!))
              .toList();
        });
      }
    } catch (e) {
      _showSnackBar('Error picking files: $e', isError: true);
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      _showSnackBar('Please select files to upload', isError: true);
      return;
    }

    if (_client == null || !_isConnected) {
      _showSnackBar('Not connected to server', isError: true);
      return;
    }

    for (final file in _selectedFiles) {
      setState(() {
        _currentUploadFile = file.path.split('/').last;
        _uploadProgress = 0.0;
      });

      try {
        final success = await _client!.uploadFileWithProgress(file);
        if (success) {
          _showSnackBar('${_currentUploadFile} uploaded successfully!');
        } else {
          _showSnackBar('Failed to upload ${_currentUploadFile}', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error uploading ${_currentUploadFile}: $e', isError: true);
      }
    }

    setState(() {
      _currentUploadFile = null;
      _uploadProgress = 0.0;
      _selectedFiles.clear();
    });

    _loadServerFiles();
  }

  Future<void> _loadServerFiles() async {
    if (_client == null || !_isConnected) return;

    try {
      final files = await _client!.getFileList();
      setState(() {
        _serverFiles = files;
      });
    } catch (e) {
      _showSnackBar('Error loading server files: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Transfer Client'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 20),
            if (_isConnected) ...[
              _buildFileSelectionCard(),
              const SizedBox(height: 20),
              if (_currentUploadFile != null) _buildUploadProgressCard(),
              if (_currentUploadFile != null) const SizedBox(height: 20),
              _buildServerFilesCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.link : Icons.link_off,
                  color: _isConnected ? Colors.green : Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected to Server' : 'Connect to Server',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isConnected) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'CONNECTED',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Server IP Address',
                hintText: '192.168.1.100',
                prefixIcon: Icon(Icons.computer),
                border: OutlineInputBorder(),
              ),
              enabled: !_isConnected,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8080',
                      prefixIcon: Icon(Icons.electrical_services),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isConnected,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: !_isConnected,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading 
                    ? null 
                    : (_isConnected ? _disconnect : _connect),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isConnected ? Icons.logout : Icons.login),
                label: Text(_isConnected ? 'Disconnect' : 'Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isConnected ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_upload, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Upload Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Files'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedFiles.isNotEmpty ? _uploadFiles : null,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Selected Files:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedFiles.length,
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  final fileName = file.path.split('/').last;
                  return ListTile(
                    leading: const Icon(Icons.file_present),
                    title: Text(fileName),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          _selectedFiles.removeAt(index);
                        });
                      },
                    ),
                    dense: true,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgressCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Upload Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Uploading: $_currentUploadFile'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildServerFilesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Server Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadServerFiles,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_serverFiles.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No files on server',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _serverFiles.length,
                itemBuilder: (context, index) {
                  final file = _serverFiles[index];
                  return ListTile(
                    leading: const Icon(Icons.file_present),
                    title: Text(file['name']),
                    subtitle: Text('${file['size']} bytes'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadFile(file['name']),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String filename) async {
    if (_client == null || !_isConnected) return;

    try {
      // For now, just show a message
      _showSnackBar('Download feature coming soon!');
    } catch (e) {
      _showSnackBar('Error downloading file: $e', isError: true);
    }
  }
}