import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      appBar: AppBar(
        backgroundColor: SpotifyTheme.background,
        title: Text('Quyền riêng tư', style: SpotifyTheme.headingSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SpotifyTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Vui lòng đăng nhập', style: TextStyle(color: SpotifyTheme.textSecondary)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thông tin tài khoản', style: SpotifyTheme.headingSmall),
                  const SizedBox(height: 24),
                  
                  // Change name section
                  _buildSettingCard(
                    title: 'Tên hiển thị',
                    subtitle: user.username,
                    icon: Icons.person_outline,
                    onTap: () => _showChangeNameDialog(user),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Change password section
                  _buildSettingCard(
                    title: 'Mật khẩu',
                    subtitle: '••••••••',
                    icon: Icons.lock_outline,
                    onTap: () => _showChangePasswordDialog(user),
                  ),

                  const SizedBox(height: 32),
                  Text('Bảo mật', style: SpotifyTheme.headingSmall),
                  const SizedBox(height: 16),

                  _buildSettingCard(
                    title: 'Email',
                    subtitle: user.email,
                    icon: Icons.email_outlined,
                    onTap: null,
                    trailing: const Icon(Icons.lock, color: SpotifyTheme.textMuted, size: 16),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Material(
      color: SpotifyTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: SpotifyTheme.cardHover,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: SpotifyTheme.textSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SpotifyTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: SpotifyTheme.bodySmall),
                  ],
                ),
              ),
              trailing ?? (onTap != null
                  ? const Icon(Icons.chevron_right, color: SpotifyTheme.textMuted)
                  : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeNameDialog(User user) {
    final controller = TextEditingController(text: user.username);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        title: Text('Đổi tên hiển thị', style: SpotifyTheme.headingSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: SpotifyTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nhập tên mới',
                filled: true,
                fillColor: SpotifyTheme.cardHover,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: SpotifyTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tên không được để trống')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              final success = await _auth.updateUsername(newName);
              if (mounted) {
                if (success) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Đã cập nhật tên thành công'),
                      backgroundColor: SpotifyTheme.primary,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Không thể cập nhật tên'),
                      backgroundColor: SpotifyTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Lưu', style: TextStyle(color: SpotifyTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(User user) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: SpotifyTheme.surface,
          title: Text('Đổi mật khẩu', style: SpotifyTheme.headingSmall),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  style: const TextStyle(color: SpotifyTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu hiện tại',
                    filled: true,
                    fillColor: SpotifyTheme.cardHover,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        color: SpotifyTheme.textSecondary,
                      ),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  style: const TextStyle(color: SpotifyTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Mật khẩu mới',
                    filled: true,
                    fillColor: SpotifyTheme.cardHover,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: SpotifyTheme.textSecondary,
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  style: const TextStyle(color: SpotifyTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Xác nhận mật khẩu mới',
                    filled: true,
                    fillColor: SpotifyTheme.cardHover,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: SpotifyTheme.textSecondary,
                      ),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy', style: TextStyle(color: SpotifyTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final currentPassword = currentPasswordController.text;
                final newPassword = newPasswordController.text;
                final confirmPassword = confirmPasswordController.text;

                if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
                  );
                  return;
                }

                if (newPassword.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mật khẩu mới phải có ít nhất 8 ký tự')),
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
                  );
                  return;
                }

                Navigator.pop(context);

                final success = await _auth.updatePassword(currentPassword, newPassword);
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Đã cập nhật mật khẩu thành công'),
                        backgroundColor: SpotifyTheme.primary,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Không thể cập nhật mật khẩu. Vui lòng kiểm tra mật khẩu hiện tại.'),
                        backgroundColor: SpotifyTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Lưu', style: TextStyle(color: SpotifyTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
