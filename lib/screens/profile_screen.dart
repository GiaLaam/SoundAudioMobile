import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: user == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Bạn chưa đăng nhập", style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                      child: const Text("Đăng nhập", style: TextStyle(color: Colors.black)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.greenAccent)),
                      child: const Text("Đăng ký", style: TextStyle(color: Colors.greenAccent)),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_circle, size: 100, color: Colors.white70),
                    Text(user.username, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        auth.logout();
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: const Text("Đăng xuất", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
