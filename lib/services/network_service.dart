import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkService {
  static final NetworkInfo _networkInfo = NetworkInfo();

  static Future<String?> getDeviceIP() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) {
        return wifiIP;
      }
      
      // Fallback to checking network interfaces
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        if (interface.addresses.isNotEmpty) {
          for (final address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4 && 
                !address.isLoopback && 
                !address.isLinkLocal) {
              return address.address;
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting device IP: $e');
      return null;
    }
  }

  static Future<String?> getWifiName() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (e) {
      print('Error getting WiFi name: $e');
      return null;
    }
  }

  static Future<List<String>> getAvailablePorts() async {
    final List<String> availablePorts = [];
    final startPort = 8000;
    final endPort = 8050;
    
    for (int port = startPort; port <= endPort; port++) {
      try {
        final serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
        await serverSocket.close();
        availablePorts.add(port.toString());
        if (availablePorts.length >= 10) break; // Limit to 10 available ports
      } catch (e) {
        // Port is not available
      }
    }
    
    return availablePorts;
  }

  static bool isValidIP(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length != 4) return false;
      
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static bool isValidPort(String port) {
    try {
      final portNum = int.tryParse(port);
      return portNum != null && portNum >= 1 && portNum <= 65535;
    } catch (e) {
      return false;
    }
  }
}