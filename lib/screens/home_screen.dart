import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/network_service.dart';
import 'server_screen.dart';
import 'client_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _deviceIP;
  String? _wifiName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    try {
      final ip = await NetworkService.getDeviceIP();
      final wifiName = await NetworkService.getWifiName();
      
      setState(() {
        _deviceIP = ip;
        _wifiName = wifiName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN File Transfer'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNetworkInfoCard(),
                  const SizedBox(height: 30),
                  _buildModeSelectionCard(),
                  const SizedBox(height: 30),
                  _buildInstructionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildNetworkInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Network Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_wifiName != null) ...[
              _buildInfoRow('WiFi Network', _wifiName!),
              const SizedBox(height: 8),
            ],
            if (_deviceIP != null) ...[
              _buildInfoRow('Device IP', _deviceIP!),
            ] else ...[
              const Text(
                'No network connection detected',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Text(value, style: const TextStyle(fontFamily: 'monospace')),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied to clipboard')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeSelectionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Select Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    title: 'Start Server',
                    subtitle: 'Receive files from other devices',
                    icon: Icons.cloud_download,
                    onPressed: _deviceIP != null ? _startServer : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildModeButton(
                    title: 'Connect as Client',
                    subtitle: 'Send files to another device',
                    icon: Icons.cloud_upload,
                    onPressed: _connectAsClient,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: onPressed,
      child: Column(
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Instructions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('1. Make sure both devices are connected to the same WiFi network'),
            const SizedBox(height: 8),
            const Text('2. Start the server on one device to receive files'),
            const SizedBox(height: 8),
            const Text('3. Use the client mode on other devices to send files'),
            const SizedBox(height: 8),
            const Text('4. Enter the server IP, port, and password to connect'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use a strong password to secure your file transfers',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startServer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServerScreen(deviceIP: _deviceIP!),
      ),
    );
  }

  void _connectAsClient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ClientScreen(),
      ),
    );
  }
}