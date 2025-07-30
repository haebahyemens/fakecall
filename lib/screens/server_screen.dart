import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/file_transfer_server.dart';
import '../services/network_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ServerScreen extends StatefulWidget {
  final String deviceIP;

  const ServerScreen({super.key, required this.deviceIP});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  FileTransferServer? _server;
  bool _isServerRunning = false;
  bool _isLoading = false;
  List<String> _receivedFiles = [];
  List<String> _availablePorts = [];

  @override
  void initState() {
    super.initState();
    _loadAvailablePorts();
    _loadReceivedFiles();
  }

  @override
  void dispose() {
    _stopServer();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailablePorts() async {
    final ports = await NetworkService.getAvailablePorts();
    setState(() {
      _availablePorts = ports;
      if (ports.isNotEmpty && !ports.contains(_portController.text)) {
        _portController.text = ports.first;
      }
    });
  }

  Future<void> _loadReceivedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final receivedDir = Directory(path.join(directory.path, 'received_files'));
      
      if (await receivedDir.exists()) {
        final files = await receivedDir.list().where((entity) => entity is File).toList();
        setState(() {
          _receivedFiles = files.map((file) => path.basename(file.path)).toList();
        });
      }
    } catch (e) {
      print('Error loading received files: $e');
    }
  }

  Future<void> _startServer() async {
    if (_passwordController.text.isEmpty) {
      _showSnackBar('Please enter a password', isError: true);
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
      _server = FileTransferServer(
        password: _passwordController.text,
        port: int.parse(_portController.text),
        onFileReceived: (filename) {
          setState(() {
            _receivedFiles.add(filename);
          });
          _showSnackBar('File received: $filename');
        },
      );

      await _server!.start();
      
      setState(() {
        _isServerRunning = true;
        _isLoading = false;
      });

      _showSnackBar('Server started successfully!');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to start server: $e', isError: true);
    }
  }

  Future<void> _stopServer() async {
    if (_server != null) {
      await _server!.stop();
      setState(() {
        _server = null;
        _isServerRunning = false;
      });
      _showSnackBar('Server stopped');
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
        title: const Text('File Transfer Server'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isServerRunning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopServer,
              tooltip: 'Stop Server',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildServerConfigCard(),
            const SizedBox(height: 20),
            if (_isServerRunning) ...[
              _buildServerInfoCard(),
              const SizedBox(height: 20),
              _buildReceivedFilesCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Server Configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'Enter a secure password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_isServerRunning,
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
                    enabled: !_isServerRunning,
                  ),
                ),
                const SizedBox(width: 12),
                if (_availablePorts.isNotEmpty && !_isServerRunning)
                  DropdownButton<String>(
                    value: _availablePorts.contains(_portController.text) 
                        ? _portController.text 
                        : null,
                    hint: const Text('Quick Select'),
                    items: _availablePorts.map((port) {
                      return DropdownMenuItem(
                        value: port,
                        child: Text(port),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _portController.text = value;
                      }
                    },
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
                    : (_isServerRunning ? _stopServer : _startServer),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServerRunning ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Server Running',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildServerInfoRow('Server IP', widget.deviceIP),
            const SizedBox(height: 8),
            _buildServerInfoRow('Port', _portController.text),
            const SizedBox(height: 8),
            _buildServerInfoRow('Password', _passwordController.text, isSensitive: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share these details with clients:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('IP: ${widget.deviceIP}'),
                  Text('Port: ${_portController.text}'),
                  Text('Password: ${_passwordController.text}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfoRow(String label, String value, {bool isSensitive = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Text(
              isSensitive ? '•' * value.length : value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSnackBar('$label copied to clipboard');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceivedFilesCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Received Files',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadReceivedFiles,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_receivedFiles.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.file_present, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No files received yet',
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
                itemCount: _receivedFiles.length,
                itemBuilder: (context, index) {
                  final filename = _receivedFiles[index];
                  return ListTile(
                    leading: const Icon(Icons.file_present),
                    title: Text(filename),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openFile(filename),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, 'received_files', filename);
      final file = File(filePath);
      
      if (await file.exists()) {
        // For now, just show file info
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('File: $filename'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Path: $filePath'),
                const SizedBox(height: 8),
                Text('Size: ${await file.length()} bytes'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showSnackBar('Error opening file: $e', isError: true);
    }
  }
}