import 'dart:developer';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'bottom_nav_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Đăng nhập",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            // Email
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: "Email",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Mật khẩu",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 30),

            // Login Button
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
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
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const BottomNavScreen()),
                          (route) => false,
                        );
                      } else if (mounted) {
                        setState(() => _error = "Sai email hoặc mật khẩu");
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 100, vertical: 14),
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
                  : const Text(
                      "Đăng nhập",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
            ),

            const SizedBox(height: 20),

            // Register Button
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
              child: const Text(
                "Chưa có tài khoản? Đăng ký ngay",
                style: TextStyle(color: Colors.white70),
              ),
            ),

            const SizedBox(height: 20),

            // --- Các nút đăng nhập MXH ---
            SignInWithAppleButton(
              style: SignInWithAppleButtonStyle.white,
              onPressed: () {
                // TODO: xử lý đăng nhập Apple
              },
              text: 'Đăng nhập với Apple',
            ),
            const SizedBox(height: 12),

            // Nút đăng nhập Google
            ElevatedButton.icon(
            icon: const FaIcon(FontAwesomeIcons.google, color: Colors.red),
            label: const Text(
              "Đăng nhập với Google",
              style: TextStyle( color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Colors.grey),
            ),
            onPressed: () {
              // TODO: xử lý đăng nhập Google
            },
          ),
          const SizedBox(height: 12),

          // Nút đăng nhập Facebook
          ElevatedButton.icon(
            icon: const Icon(Icons.facebook, color: Colors.white, size: 26),
            label: const Text(
              "Đăng nhập với Facebook",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              // TODO: xử lý đăng nhập Facebook
            },
          ),
          ],
        )
      ),
    );
  }
}
