# LAN File Transfer

A Flutter application for transferring files between devices over LAN without internet connection. Features secure password-based authentication and real-time transfer progress tracking.

## Features

- 🌐 **LAN-based Transfer**: Transfer files between devices on the same WiFi network without internet
- 🔒 **Password Protection**: Secure transfers with password authentication
- 📱 **Cross-Platform**: Works on Android and iOS devices
- 📊 **Progress Tracking**: Real-time upload/download progress monitoring
- 🖥️ **Server Mode**: Turn any device into a file receiving server
- 📤 **Client Mode**: Connect to servers and send multiple files
- 🔍 **Network Discovery**: Automatic IP detection and available port scanning
- 📁 **File Management**: View received files and server file listings

## How It Works

### Server Mode
1. Start the app and select "Start Server"
2. Set a secure password and choose a port
3. Share your IP address, port, and password with clients
4. Receive files from connected clients

### Client Mode
1. Select "Connect as Client"
2. Enter the server's IP address, port, and password
3. Select files to upload using the file picker
4. Monitor transfer progress in real-time

## Setup and Installation

### Prerequisites
- Flutter SDK (>=3.10.0)
- Dart SDK (>=3.0.0)
- Android Studio / Xcode for mobile development

### Installation

1. **Clone or download the project files**
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

### For Android Development
Ensure you have the Android SDK and necessary build tools installed. The app requires the following permissions:
- Internet access
- Network state access
- File read/write permissions
- WiFi state access

### For iOS Development
Ensure you have Xcode installed with iOS SDK. The app includes proper permissions for:
- Network access
- File system access
- Photo library access (for media files)

## Dependencies

```yaml
dependencies:
  flutter: sdk: flutter
  
  # HTTP server and client
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  shelf_static: ^1.1.2
  http: ^1.1.0
  
  # File operations
  file_picker: ^6.1.1
  path_provider: ^2.1.1
  path: ^1.8.3
  
  # Network utilities
  network_info_plus: ^4.1.0
  
  # Security
  crypto: ^3.0.3
  
  # UI components
  cupertino_icons: ^1.0.2
  flutter_dropzone: ^4.0.1
  mime: ^1.0.4
```

## Architecture

### Core Components

1. **FileTransferServer** (`lib/services/file_transfer_server.dart`)
   - HTTP server implementation using Shelf framework
   - Handles file uploads, downloads, and authentication
   - Supports multipart form data parsing
   - Password-based security with SHA-256 hashing

2. **FileTransferClient** (`lib/services/file_transfer_client.dart`)
   - HTTP client for connecting to servers
   - File upload with progress tracking
   - Authentication handling
   - Server file listing and management

3. **NetworkService** (`lib/services/network_service.dart`)
   - Network utility functions
   - IP address detection
   - Available port scanning
   - Network validation

### UI Screens

1. **HomeScreen** - Main app entry point with mode selection
2. **ServerScreen** - Server configuration and management
3. **ClientScreen** - Client connection and file transfer

## Security Features

- **Password Authentication**: All transfers require password authentication
- **Token-based Sessions**: Secure session management with time-based tokens
- **Hash-based Security**: Passwords are hashed using SHA-256
- **Local Network Only**: Designed for LAN use, no internet connectivity required

## Usage Examples

### Starting a Server
1. Open the app and tap "Start Server"
2. Enter a strong password (e.g., "MySecurePassword123")
3. Select or enter a port number (default: 8080)
4. Tap "Start Server"
5. Share the displayed connection details with clients

### Connecting as Client
1. Open the app and tap "Connect as Client"
2. Enter the server's IP address (e.g., "192.168.1.100")
3. Enter the port number (e.g., "8080")
4. Enter the password
5. Tap "Connect"

### Transferring Files
1. After connecting, tap "Select Files"
2. Choose one or multiple files from your device
3. Tap "Upload" to start the transfer
4. Monitor progress in real-time

## Troubleshooting

### Connection Issues
- Ensure both devices are on the same WiFi network
- Check that the IP address and port are correct
- Verify the password is entered correctly
- Try a different port if the current one is busy

### File Transfer Problems
- Check available storage space on the receiving device
- Ensure file permissions are granted
- Try smaller files first to test the connection
- Check firewall settings if transfers fail

### Network Detection
- Grant network and location permissions when prompted
- Restart the app if network information isn't detected
- Manually enter IP address if auto-detection fails

## Development

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── server_screen.dart
│   └── client_screen.dart
└── services/                 # Core services
    ├── file_transfer_server.dart
    ├── file_transfer_client.dart
    └── network_service.dart
```

### Building for Release

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## Limitations

- Designed for LAN use only (same WiFi network)
- File size limited by device memory and storage
- No file compression (transfers raw file data)
- Basic file management (no folders/directory structure)

## Future Enhancements

- [ ] File compression support
- [ ] Directory/folder transfer
- [ ] Transfer resume capability
- [ ] QR code sharing for connection details
- [ ] Dark mode support
- [ ] Multiple simultaneous transfers
- [ ] File preview functionality

## License

This project is open source and available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

---

**Note**: This app is designed for local network file transfers. Always use strong passwords and ensure you trust the devices you're transferring files with.
