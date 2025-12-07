import 'package:flutter/material.dart';

/// Banner thông báo khi nhạc đang phát ở thiết bị khác
/// Giống như Spotify: "Listening on [Device Name]"
class PlaybackNotificationBanner extends StatefulWidget {
  final String deviceName;
  final String? songName;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const PlaybackNotificationBanner({
    Key? key,
    required this.deviceName,
    this.songName,
    this.imageUrl,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<PlaybackNotificationBanner> createState() => _PlaybackNotificationBannerState();
}

class _PlaybackNotificationBannerState extends State<PlaybackNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _dismissBanner() async {
    await _animationController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1DB954).withOpacity(0.9), // Spotify green
                const Color(0xFF1ED760).withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Biểu tượng hoặc hình ảnh bài hát
              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    widget.imageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildIcon(),
                  ),
                )
              else
                _buildIcon(),
              
              const SizedBox(width: 12),
              
              // Thông tin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_iphone,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Đang phát trên ${widget.deviceName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (widget.songName != null && widget.songName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.songName!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Nút đóng
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: _dismissBanner,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.music_note,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
