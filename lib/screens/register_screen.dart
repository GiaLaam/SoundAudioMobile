import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Đăng ký", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            _buildInput(_usernameController, "Họ và tên"),
            const SizedBox(height: 16),
            _buildInput(_emailController, "Email"),
            const SizedBox(height: 16),
            _buildInput(_passwordController, "Mật khẩu", isPassword: true),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isLoading 
                ? null 
                : () async {
                    setState(() => _isLoading = true);
                    final success = await _auth.register(
                      _usernameController.text,
                      _emailController.text,
                      _passwordController.text,
                    );
                    
                    if (mounted) setState(() => _isLoading = false);
                    
                    if (success && mounted) {
                      // Đóng màn hình register
                      Navigator.pop(context);
                      
                      // Chuyển về tab Trang chủ
                      AppScaffold.scaffoldKey.currentState?.switchToHomeTab();
                      
                      // Hiển thị thông báo
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đăng ký thành công!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      // Show error message if registration fails
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đăng ký thất bại. Vui lòng thử lại.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 14),
              ),
              child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text("Đăng ký", style: TextStyle(color: Colors.black, fontSize: 16)),
            ),
            
            const SizedBox(height: 20),

            // Login Button
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text(
                "Đã có tài khoản? Đăng nhập ngay",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}
