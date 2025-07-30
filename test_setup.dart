import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  print('🚀 LAN File Transfer - Setup Verification\n');
  
  // Check if we're in a Flutter project
  final pubspecFile = File('pubspec.yaml');
  if (!await pubspecFile.exists()) {
    print('❌ Error: pubspec.yaml not found. Please run this from the project root.');
    exit(1);
  }
  
  print('✅ pubspec.yaml found');
  
  // Check main directories
  final directories = ['lib', 'lib/screens', 'lib/services'];
  for (final dir in directories) {
    final directory = Directory(dir);
    if (await directory.exists()) {
      print('✅ Directory $dir exists');
    } else {
      print('❌ Directory $dir missing');
    }
  }
  
  // Check main files
  final files = [
    'lib/main.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/server_screen.dart',
    'lib/screens/client_screen.dart',
    'lib/services/file_transfer_server.dart',
    'lib/services/file_transfer_client.dart',
    'lib/services/network_service.dart',
  ];
  
  for (final file in files) {
    final fileObj = File(file);
    if (await fileObj.exists()) {
      print('✅ File $file exists');
    } else {
      print('❌ File $file missing');
    }
  }
  
  // Check platform-specific files
  final androidManifest = File('android/app/src/main/AndroidManifest.xml');
  final iosInfo = File('ios/Runner/Info.plist');
  
  if (await androidManifest.exists()) {
    print('✅ Android manifest exists');
  } else {
    print('⚠️  Android manifest missing (needed for Android builds)');
  }
  
  if (await iosInfo.exists()) {
    print('✅ iOS Info.plist exists');
  } else {
    print('⚠️  iOS Info.plist missing (needed for iOS builds)');
  }
  
  print('\n📋 Setup Summary:');
  print('1. Run "flutter pub get" to install dependencies');
  print('2. Run "flutter run" to start the app');
  print('3. For Android: Ensure Android SDK is configured');
  print('4. For iOS: Ensure Xcode is installed');
  
  print('\n🎯 Ready to transfer files over LAN!');
  print('Remember to connect devices to the same WiFi network.');
}