import 'package:flutter/material.dart';

/// Dialog hiển thị danh sách thiết bị
/// Giống như Spotify: "Connect to a device"
class DevicesDialog extends StatelessWidget {
  final String currentDeviceId;
  final String currentDeviceName;
  final List<Map<String, dynamic>> availableDevices; // {deviceId, deviceName, isActive}
  final Function(String deviceId)? onDeviceSelected;

  const DevicesDialog({
    Key? key,
    required this.currentDeviceId,
    required this.currentDeviceName,
    this.availableDevices = const [],
    this.onDeviceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Phân loại thiết bị: thiết bị hiện tại và thiết bị khác
    Map<String, dynamic>? currentDevice;
    try {
      currentDevice = availableDevices.firstWhere(
        (device) => device['isCurrentDevice'] == true,
      );
    } catch (e) {
      currentDevice = null;
    }
    
    final otherDevices = availableDevices
        .where((device) => device['isCurrentDevice'] != true)
        .toList();
    
    return Dialog(
      backgroundColor: const Color(0xFF282828),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.devices,
                  color: Color(0xFF1DB954),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Thiết bị phát nhạc',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Thiết bị hiện tại
            _buildSectionTitle('Thiết bị này'),
            const SizedBox(height: 8),
            _buildDeviceTile(
              deviceName: currentDevice?['deviceName'] ?? currentDeviceName,
              deviceId: currentDevice?['deviceId'] ?? currentDeviceId,
              isActive: currentDevice?['isActive'] ?? true,
              isCurrent: true,
              onTap: () {
                // Thiết bị hiện tại, không cần làm gì
                Navigator.pop(context);
              },
            ),
            
            // Các thiết bị khác (đã lọc bỏ thiết bị hiện tại)
            if (otherDevices.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Thiết bị khác'),
              const SizedBox(height: 8),
              ...otherDevices.map((device) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildDeviceTile(
                    deviceName: device['deviceName'] ?? 'Unknown Device',
                    deviceId: device['deviceId'] ?? '',
                    isActive: device['isActive'] ?? false,
                    isCurrent: false,
                    onTap: () {
                      // Ưu tiên dùng connectionId để transfer playback
                      final targetId = device['connectionId'] ?? device['deviceId'] ?? '';
                      onDeviceSelected?.call(targetId);
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
            ] else ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_other,
                      color: Colors.white.withOpacity(0.3),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Không tìm thấy thiết bị khác',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đăng nhập trên thiết bị khác để xem ở đây',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDeviceTile({
    required String deviceName,
    required String deviceId,
    required bool isActive,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isCurrent 
              ? const Color(0xFF1DB954).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent 
                ? const Color(0xFF1DB954)
                : Colors.white.withOpacity(0.1),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon thiết bị
            Icon(
              _getDeviceIcon(deviceName),
              color: isActive 
                  ? const Color(0xFF1DB954) 
                  : Colors.white70,
              size: 32,
            ),
            
            const SizedBox(width: 16),
            
            // Tên thiết bị
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceName,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isCurrent)
                    const Text(
                      'Thiết bị này',
                      style: TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 12,
                      ),
                    )
                  else if (isActive)
                    const Text(
                      'Đang phát',
                      style: TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            
            // Indicator
            if (isActive)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volume_up,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('iphone') || name.contains('mobile')) {
      return Icons.phone_iphone;
    } else if (name.contains('ipad') || name.contains('tablet')) {
      return Icons.tablet_mac;
    } else if (name.contains('mac') || name.contains('laptop') || name.contains('pc')) {
      return Icons.laptop_mac;
    } else if (name.contains('web') || name.contains('browser')) {
      return Icons.language;
    }
    return Icons.devices;
  }
}
