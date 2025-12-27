import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/signalr_service.dart';
import '../widgets/app_scaffold.dart';
import '../theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  String? _error;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: SpotifyTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Logo
              const Icon(Icons.headphones, color: SpotifyTheme.primary, size: 64),
              const SizedBox(height: 24),
              Text(
                "Đăng nhập vào\nSoundAudio",
                style: SpotifyTheme.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Email field
              Text("Email hoặc tên người dùng", style: SpotifyTheme.bodyMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: SpotifyTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: "Email hoặc tên người dùng",
                  filled: true,
                  fillColor: SpotifyTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: SpotifyTheme.textPrimary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password field
              Text("Mật khẩu", style: SpotifyTheme.bodyMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: SpotifyTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: "Mật khẩu",
                  filled: true,
                  fillColor: SpotifyTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: SpotifyTheme.textPrimary, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: SpotifyTheme.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SpotifyTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: SpotifyTheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: SpotifyTheme.error))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpotifyTheme.primary,
                  foregroundColor: SpotifyTheme.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  disabledBackgroundColor: SpotifyTheme.primary.withOpacity(0.5),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(SpotifyTheme.background),
                        ),
                      )
                    : const Text("Đăng nhập", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),

              const SizedBox(height: 24),
              
              // Forgot password
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text("Quên mật khẩu?", style: SpotifyTheme.bodyLarge.copyWith(decoration: TextDecoration.underline)),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: SpotifyTheme.divider),
              const SizedBox(height: 24),

              // Social login buttons
              _buildSocialButton(
                icon: Icons.g_mobiledata,
                label: 'Tiếp tục với Google',
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
                onTap: () {},
              ),

              const SizedBox(height: 32),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Chưa có tài khoản? ", style: SpotifyTheme.bodyMedium),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
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
    Color? color,
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
              Icon(icon, color: color ?? SpotifyTheme.textPrimary, size: 24),
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

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await _auth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) setState(() => _isLoading = false);

    if (success && mounted) {
      await SignalRService().connect();
      Navigator.pop(context);
      AppScaffold.scaffoldKey.currentState?.switchToHomeTab();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đăng nhập thành công!'),
          backgroundColor: SpotifyTheme.primary,
        ),
      );
    } else if (mounted) {
      setState(() => _error = "Sai email hoặc mật khẩu");
    }
  }
}
