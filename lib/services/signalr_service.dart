import 'dart:async';
import 'dart:io';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'auth_service.dart';

class SignalRService {
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  HubConnection? _hubConnection;
  String? _deviceId;
  String? _deviceName; // Thêm tên thiết bị thực
  bool _isConnected = false;
  
  // Có thể thay đổi endpoint nếu cần
  static const String _hubEndpoint = 'hubs/playback'; // Endpoint từ Web
  
  // Stream để thông báo khi cần dừng phát nhạc (với thông tin device)
  final StreamController<Map<String, dynamic>> _stopPlaybackController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stopPlaybackStream => _stopPlaybackController.stream;
  
  // Stream để thông báo thiết bị khác đang phát bài gì
  final StreamController<Map<String, dynamic>> _playbackInfoController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get playbackInfoStream => _playbackInfoController.stream;

  // Stream để nhận lệnh phát nhạc từ thiết bị khác (transfer playback)
  final StreamController<Map<String, dynamic>> _startPlaybackRemoteController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get startPlaybackRemoteStream => _startPlaybackRemoteController.stream;

  // Stream để nhận đồng bộ vị trí phát từ thiết bị khác
  final StreamController<Map<String, dynamic>> _positionSyncController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get positionSyncStream => _positionSyncController.stream;

  // Callback đã xóa - sử dụng stream thay thế

  Future<void> initialize() async {
    // Lấy hoặc tạo Device ID duy nhất
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString('device_id', _deviceId!);
    }

    // Lấy tên thiết bị thực (iPhone 16 Pro Max, Samsung Galaxy, v.v.)
    await _initDeviceInfo();

    print('📱 Device ID: $_deviceId');
    print('📱 Device Name: $_deviceName');
  }

  // Lấy thông tin thiết bị
  Future<void> _initDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
      _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      // Sử dụng tên có thể đọc được thay vì machine identifier
      _deviceName = _getReadableIOSDeviceName(iosInfo.utsname.machine);
    } else {
      _deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
      _deviceName = 'Web Browser';
    }
  }

  // Chuyển đổi model code iOS sang tên dễ đọc
  String _getReadableIOSDeviceName(String? modelCode) {
    // Map các model code phổ biến
    final Map<String, String> deviceMap = {
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      'iPad13,18': 'iPad Pro 12.9-inch (6th generation)',
      'iPad13,16': 'iPad Pro 11-inch (4th generation)',
    };

    // Nếu tìm thấy trong map thì trả về tên đẹp, không thì trả về model code
    if (modelCode != null && deviceMap.containsKey(modelCode)) {
      return deviceMap[modelCode]!;
    }
    
    // Fallback: iPhone14,7 -> iPhone 14.7
    if (modelCode != null && modelCode.startsWith('iPhone')) {
      return modelCode.replaceAll('iPhone', 'iPhone ').replaceAll(',', '.');
    }
    if (modelCode != null && modelCode.startsWith('iPad')) {
      return modelCode.replaceAll('iPad', 'iPad ').replaceAll(',', '.');
    }
    
    return modelCode != null && modelCode.isNotEmpty ? modelCode : 'iOS Device';
  }

  Future<void> connect() async {
    final user = AuthService().currentUser;
    if (user == null) {
      print('⚠️ SignalR: User not logged in');
      return;
    }

    // Ngắt kết nối cũ nếu có
    if (_hubConnection != null) {
      print('🔄 SignalR: Disconnecting old connection...');
      try {
        await _hubConnection!.stop();
      } catch (e) {
        print('⚠️ Error stopping old connection: $e');
      }
      _hubConnection = null;
      _isConnected = false;
    }

    try {
      // URL của SignalR Hub trên backend
      final serverUrl = 'https://difficulties-filled-did-announce.trycloudflare.com/$_hubEndpoint';
      
      print('🔄 Attempting to connect SignalR...');
      print('   Server: $serverUrl');
      print('   Device: $_deviceId');
      print('   Token preview: ${user.token.substring(0, 50)}...');
      
      _hubConnection = HubConnectionBuilder()
          .withUrl(serverUrl, options: HttpConnectionOptions(
            accessTokenFactory: () async {
              print('   🔑 Providing JWT token for SignalR');
              return user.token;
            },
          ))
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
          .build();

      // Lắng nghe sự kiện "StopPlayback" từ server
      _hubConnection!.on('StopPlayback', (arguments) {
        print('📩 StopPlayback event received!');
        print('   Arguments: $arguments');
        print('   My deviceId: $_deviceId');
        
        if (arguments != null && arguments.isNotEmpty) {
          final sendingDeviceId = arguments[0] as String;
          print('🛑 Received StopPlayback from device: $sendingDeviceId');
          
          // Xử lý tất cả - không cần kiểm tra deviceId vì server đã lọc
          print('⏸️ Stopping playback on this device');
          _stopPlaybackController.add({
            'deviceId': sendingDeviceId,
            'deviceName': 'Another device',
          });
        }
      });

      // Lắng nghe sự kiện "PausePlayback" từ server (có thêm thông tin device)
      _hubConnection!.on('PausePlayback', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          try {
            final data = arguments[0] as Map<String, dynamic>;
            final deviceName = data['deviceName'] ?? data['device'] ?? 'Another device';
            final songName = data['songName'] ?? '';
            final sourceDeviceId = data['sourceDeviceId'] ?? '';
            
            // Bỏ qua nếu từ chính thiết bị này
            if (sourceDeviceId == _deviceId) return;
            
            print('🛑 Received PausePlayback:');
            print('   Device: $deviceName');
            print('   Song: $songName');
            
            _stopPlaybackController.add({
              'deviceId': sourceDeviceId,
              'deviceName': deviceName,
              'songName': songName,
              'reason': data['reason'] ?? 'Playing on another device',
            });
          } catch (e) {
            print('⚠️ Error parsing PausePlayback: $e');
          }
        }
      });

      // Lắng nghe sự kiện "StartPlaybackRemote" - khi được yêu cầu phát từ thiết bị khác
      _hubConnection!.on('StartPlaybackRemote', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          try {
            final data = arguments[0] as Map<String, dynamic>;
            print('🎵 Received StartPlaybackRemote:');
            print('   Song ID: ${data['songId']}');
            print('   Position: ${data['positionMs']}ms');
            print('   From: ${data['sourceDevice']}');
            
            _startPlaybackRemoteController.add(data);
          } catch (e) {
            print('⚠️ Error parsing StartPlaybackRemote: $e');
          }
        }
      });
      
      // Lắng nghe sự kiện "PlaybackStarted" - khi thiết bị khác bắt đầu phát
      _hubConnection!.on('PlaybackStarted', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          try {
            final deviceId = arguments[0] as String;
            
            // Bỏ qua nếu từ chính thiết bị này
            if (deviceId == _deviceId) return;
            
            print('🎵 Received PlaybackStarted from device: $deviceId');
            
            // Parse thông tin bài hát nếu có
            if (arguments.length >= 2 && arguments[1] is Map) {
              final songInfo = Map<String, dynamic>.from(arguments[1] as Map);
              print('   Song: ${songInfo['songName'] ?? 'Unknown'}');
              print('   Device is playing on another device');
              
              _playbackInfoController.add({
                'deviceId': deviceId,
                'songInfo': songInfo,
              });
            }
          } catch (e) {
            print('⚠️ Error parsing PlaybackStarted event: $e');
          }
        }
      });

      // Lắng nghe đồng bộ vị trí phát từ thiết bị khác
      _hubConnection!.on('PlaybackPositionSync', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          try {
            final data = arguments[0] as Map<String, dynamic>;
            _positionSyncController.add(data);
          } catch (e) {
            print('⚠️ Error parsing PlaybackPositionSync: $e');
          }
        }
      });

      // Xử lý khi kết nối lại
      _hubConnection!.onreconnecting(({error}) {
        print('🔄 SignalR reconnecting... Error: $error');
        _isConnected = false;
      });

      _hubConnection!.onreconnected(({connectionId}) {
        print('✅ SignalR reconnected! ConnectionId: $connectionId');
        _isConnected = true;
        _registerDevice();
      });

      _hubConnection!.onclose(({error}) {
        print('❌ SignalR connection closed. Error: $error');
        _isConnected = false;
      });

      // Bắt đầu kết nối
      print('   ⏳ Starting connection...');
      await _hubConnection!.start();
      _isConnected = true;
      print('✅ SignalR connected successfully!');
      print('   ConnectionId: ${_hubConnection!.connectionId}');
      print('   State: ${_hubConnection!.state}');

      // Đăng ký thiết bị với server
      await _registerDevice();
      
    } catch (e) {
      print('❌ SignalR connection failed: $e');
      print('');
      print('🔧 Troubleshooting:');
      print('   Current endpoint: $_hubEndpoint');
      print('   1. Kiểm tra Web đang dùng endpoint nào (DevTools > Network > WS)');
      print('   2. Thử đổi _hubEndpoint thành: playbackHub, hubs/music, api/musicHub');
      print('   3. Kiểm tra CORS và JWT authentication');
      print('   4. Backend cần có: app.MapHub<MusicHub>("/$_hubEndpoint")');
      print('');
      print('ℹ️ App will continue without real-time device sync');
      _isConnected = false;
    }
  }

  Future<void> _registerDevice() async {
    if (_hubConnection == null || !_isConnected || _deviceId == null) {
      print('⚠️ Cannot register device - not connected');
      return;
    }

    try {
      print('📝 Attempting to register device with server...');
      print('   Device ID: $_deviceId');
      print('   Device Name: $_deviceName');
      
      // Gọi RegisterDevice với 3 tham số: deviceId, deviceName, deviceType
      await _hubConnection!.invoke('RegisterDevice', args: <Object>[
        _deviceId!,
        _deviceName ?? 'Mobile App',
        'Mobile',
      ]);
      print('✅ Device registered successfully');
    } catch (e) {
      print('⚠️ RegisterDevice failed: $e');
      print('   Mobile will still receive events');
    }
  }

  // Gọi khi thiết bị này bắt đầu phát nhạc
  Future<void> notifyPlaybackStarted({
    String? songId,
    String? songName,
    String? artistName,
    String? imageUrl,
  }) async {
    if (_hubConnection == null || !_isConnected || _deviceId == null) {
      print('⚠️ SignalR not connected - cannot notify playback');
      return;
    }

    try {
      print('🎵 Notifying server about playback...');
      print('   Device ID: $_deviceId');
      print('   Device Name: $_deviceName');
      if (songName != null) {
        print('   Now playing: $songName');
      }
      
      // Gọi NotifyPlaybackStarted với đúng signature: (deviceId, deviceName)
      await _hubConnection!.invoke('NotifyPlaybackStarted', args: <Object>[
        _deviceId!,
        _deviceName ?? 'Mobile App',
      ]);
      print('✅ NotifyPlaybackStarted called successfully');
      
    } catch (e) {
      print('❌ Error notifying playback: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      if (_hubConnection != null) {
        await _hubConnection!.stop();
        _isConnected = false;
        print('🔌 SignalR disconnected');
      }
    } catch (e) {
      print('❌ Error disconnecting SignalR: $e');
    }
  }

  bool get isConnected => _isConnected;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  
  // Getters để dùng trong UI
  String? get currentDeviceId => _deviceId;
  String? get currentDeviceName => _deviceName;

  // Lấy danh sách thiết bị khả dụng (bao gồm cả thiết bị hiện tại)
  Future<List<DeviceInfo>> getAvailableDevices() async {
    // Lấy tất cả thiết bị từ server (đã bao gồm thiết bị hiện tại)
    final connectedDevices = await getConnectedDevices();
    
    if (connectedDevices.isEmpty) {
      // Nếu server không trả về gì, thêm thiết bị hiện tại
      return [
        DeviceInfo(
          deviceId: _deviceId ?? 'unknown',
          connectionId: _hubConnection?.connectionId ?? '',
          deviceName: _deviceName ?? 'This Device',
          isActive: true,
          isCurrentDevice: true,
        ),
      ];
    }
    
    // Map kết quả từ server
    return connectedDevices.map((device) => DeviceInfo(
      deviceId: device['deviceId'] ?? device['connectionId'] ?? '',
      connectionId: device['connectionId'] ?? '',
      deviceName: device['deviceName'] ?? 'Unknown Device',
      isActive: device['isActive'] ?? false,
      isCurrentDevice: device['isCurrentDevice'] ?? false,
    )).toList();
  }
  
  // Gửi đồng bộ vị trí phát đến các thiết bị khác
  Future<void> syncPlaybackPosition(String songId, int positionMs, bool isPlaying) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!.invoke('SyncPlaybackPosition', args: <Object>[
        songId,
        positionMs,
        isPlaying,
      ]);
    } catch (e) {
      // Ignore errors - sync is not critical
    }
  }

  // Chuyển phát nhạc sang thiết bị khác
  Future<bool> transferPlayback(
    String targetDeviceId,
    String songId,
    Duration position,
    bool isPlaying, {
    String? songName,
    String? imageUrl,
    String? artistName,
  }) async {
    if (_hubConnection == null || !_isConnected) {
      print('⚠️ SignalR not connected - cannot transfer playback');
      return false;
    }

    try {
      print('🔄 Transferring playback to device: $targetDeviceId');
      print('   Song: $songId, Position: ${position.inSeconds}s, Playing: $isPlaying');
      print('   SongName: $songName, ImageUrl: $imageUrl');
      
      await _hubConnection!.invoke('TransferPlayback', args: <Object>[
        targetDeviceId,
        songId,
        position.inMilliseconds,
        isPlaying,
        songName ?? '',
        imageUrl ?? '',
        artistName ?? '',
      ]);
      
      print('✅ Playback transferred successfully');
      return true;
    } catch (e) {
      print('❌ Error transferring playback: $e');
      return false;
    }
  }

  // Lấy danh sách thiết bị đang kết nối
  Future<List<Map<String, dynamic>>> getConnectedDevices() async {
    print('📱 getConnectedDevices called');
    print('   _hubConnection: ${_hubConnection != null ? 'exists' : 'null'}');
    print('   _isConnected: $_isConnected');
    
    if (_hubConnection == null || !_isConnected) {
      print('⚠️ SignalR not connected - cannot get devices');
      return [];
    }

    try {
      print('📱 Fetching connected devices from server...');
      
      // Thử gọi method GetConnectedDevices từ server
      final result = await _hubConnection!.invoke('GetConnectedDevices');
      
      if (result == null) {
        print('⚠️ Server returned null for GetConnectedDevices');
        return [];
      }

      // Parse result thành List<Map<String, dynamic>>
      final List<Map<String, dynamic>> devices = [];
      
      if (result is List) {
        for (var item in result) {
          if (item is Map) {
            final device = Map<String, dynamic>.from(item);
            // Thêm tất cả thiết bị (bao gồm cả thiết bị hiện tại)
            devices.add(device);
          }
        }
      }
      
      print('✅ Found ${devices.length} devices');
      for (var device in devices) {
        final isCurrent = device['isCurrentDevice'] == true ? ' (current)' : '';
        print('   - ${device['deviceName']} (${device['deviceId']})$isCurrent');
      }
      
      return devices;
    } catch (e) {
      print('❌ Error getting connected devices: $e');
      print('   Backend cần có method: GetConnectedDevices()');
      print('   Method này trả về List<object> với: deviceId, deviceName, isActive');
      return [];
    }
  }

  void dispose() {
    _stopPlaybackController.close();
    _playbackInfoController.close();
    _startPlaybackRemoteController.close();
    disconnect();
  }
}

// Model class cho thông tin thiết bị
class DeviceInfo {
  final String deviceId;
  final String connectionId;
  final String deviceName;
  final bool isActive;
  final bool isCurrentDevice;
  
  DeviceInfo({
    required this.deviceId,
    this.connectionId = '',
    required this.deviceName,
    required this.isActive,
    this.isCurrentDevice = false,
  });
}
