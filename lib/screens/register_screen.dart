import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../theme.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

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
                "Đăng ký tài khoản\nmiễn phí",
                style: SpotifyTheme.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Username field
              Text("Họ và tên", style: SpotifyTheme.bodyMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: SpotifyTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: "Nhập họ và tên",
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

              // Email field
              Text("Email", style: SpotifyTheme.bodyMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: SpotifyTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: "Nhập địa chỉ email",
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
                  hintText: "Tạo mật khẩu",
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
              const SizedBox(height: 8),
              Text(
                "Sử dụng ít nhất 8 ký tự bao gồm chữ, số và ký tự đặc biệt",
                style: SpotifyTheme.bodySmall,
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

              // Register Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
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
                    : const Text("Đăng ký", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),

              const SizedBox(height: 24),

              // Terms and privacy
              Text(
                "Bằng việc đăng ký, bạn đồng ý với Điều khoản sử dụng và Chính sách bảo mật của chúng tôi.",
                style: SpotifyTheme.bodySmall,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Đã có tài khoản? ", style: SpotifyTheme.bodyMedium),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      "Đăng nhập",
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

  Future<void> _handleRegister() async {
    // Validate fields
    if (_usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = "Vui lòng điền đầy đủ thông tin");
      return;
    }

    if (_passwordController.text.length < 8) {
      setState(() => _error = "Mật khẩu phải có ít nhất 8 ký tự");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await _auth.register(
      _usernameController.text,
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pop(context);
      AppScaffold.scaffoldKey.currentState?.switchToHomeTab();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đăng ký thành công!'),
          backgroundColor: SpotifyTheme.primary,
        ),
      );
    } else if (mounted) {
      setState(() => _error = "Đăng ký thất bại. Vui lòng thử lại.");
    }
  }
}
