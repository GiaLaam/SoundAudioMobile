import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'recently_played_screen.dart';
import 'privacy_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.userStream,
      initialData: _auth.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Scaffold(
          backgroundColor: SpotifyTheme.background,
          body: user == null ? _buildLoggedOutView() : _buildLoggedInView(user),
        );
      },
    );
  }

  Widget _buildLoggedOutView() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: SpotifyTheme.cardHover,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 60,
                  color: SpotifyTheme.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Đăng nhập vào SoundAudio',
                style: SpotifyTheme.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Nghe nhạc không giới hạn, tạo playlist và đồng bộ trên mọi thiết bị',
                style: SpotifyTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              _buildSocialButton(
                icon: Icons.g_mobiledata,
                label: 'Tiếp tục với Google',
                color: SpotifyTheme.textPrimary,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildSocialButton(
                icon: Icons.facebook,
                label: 'Tiếp tục với Facebook',
                color: const Color(0xFF1877F2),
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildSocialButton(
                icon: Icons.apple,
                label: 'Tiếp tục với Apple',
                color: SpotifyTheme.textPrimary,
                onTap: () {},
              ),

              const SizedBox(height: 24),
              const Divider(color: SpotifyTheme.divider),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                      fullscreenDialog: true,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpotifyTheme.primary,
                    foregroundColor: SpotifyTheme.background,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Đăng nhập bằng email'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Chưa có tài khoản? ", style: SpotifyTheme.bodyMedium),
                  GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                        fullscreenDialog: true,
                      ),
                    ),
                    child: const Text(
                      "Đăng ký",
                      style: TextStyle(
                        color: SpotifyTheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: SpotifyTheme.textMuted),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: SpotifyTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInView(User user) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  SpotifyTheme.primary.withOpacity(0.6),
                  SpotifyTheme.background,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: SpotifyTheme.textPrimary),
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: SpotifyTheme.cardHover,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: SpotifyTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user.username, style: SpotifyTheme.headingMedium),
                  const SizedBox(height: 4),
                  Text(user.email, style: SpotifyTheme.bodyMedium),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem('0', 'Playlist'),
                      Container(
                        width: 1,
                        height: 40,
                        color: SpotifyTheme.divider,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                      ),
                      _buildStatItem('0', 'Người theo dõi'),
                      Container(
                        width: 1,
                        height: 40,
                        color: SpotifyTheme.divider,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                      ),
                      _buildStatItem('0', 'Đang theo dõi'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: SpotifyTheme.textMuted),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: const Text('Chỉnh sửa'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildMenuItem(
                Icons.history,
                'Đã nghe gần đây',
                () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const RecentlyPlayedScreen()),
                  );
                },
              ),
              _buildMenuItem(
                Icons.privacy_tip_outlined,
                'Quyền riêng tư',
                () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: SpotifyTheme.divider, indent: 16, endIndent: 16),
              const SizedBox(height: 16),
              _buildMenuItem(
                Icons.logout,
                'Đăng xuất',
                () => _showLogoutDialog(),
                textColor: SpotifyTheme.error,
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: SpotifyTheme.headingSmall),
        const SizedBox(height: 4),
        Text(label, style: SpotifyTheme.bodySmall),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, {Color? textColor}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: textColor ?? SpotifyTheme.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: SpotifyTheme.bodyLarge.copyWith(color: textColor),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: textColor ?? SpotifyTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        title: Text('Đăng xuất', style: SpotifyTheme.headingSmall),
        content: Text(
          'Bạn có chắc muốn đăng xuất khỏi tài khoản?',
          style: SpotifyTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: SpotifyTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _auth.logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Đã đăng xuất thành công'),
                    backgroundColor: SpotifyTheme.primary,
                  ),
                );
              }
            },
            child: const Text('Đăng xuất', style: TextStyle(color: SpotifyTheme.error)),
          ),
        ],
      ),
    );
  }
}
