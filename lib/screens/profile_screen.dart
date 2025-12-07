import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

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
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Hồ sơ',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tính năng Cài đặt đang được phát triển...')),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: user == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_circle, size: 120, color: Colors.white38),
                          const SizedBox(height: 20),
                          const Text(
                            "Bạn chưa đăng nhập",
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                                fullscreenDialog: true,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: const Text("Đăng nhập", style: TextStyle(color: Colors.black, fontSize: 16)),
                          ),
                          const SizedBox(height: 15),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                                fullscreenDialog: true,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.greenAccent),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: const Text("Đăng ký", style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[800],
                            child: const Icon(Icons.person, size: 70, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.email,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Hiển thị dialog xác nhận
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                    'Bạn có chắc muốn đăng xuất?',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Đăng xuất', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                _auth.logout();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã đăng xuất thành công'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.logout, color: Colors.white),
                            label: const Text(
                              "Đăng xuất",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
