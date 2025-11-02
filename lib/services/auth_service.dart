import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String token;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Debug log to see raw json data
    print('Raw JSON data: $json');
    
    // Handle both direct data and nested data structures
    final userData = json['user'] ?? json;
    
    return User(
      id: userData['id']?.toString() ?? '',
      username: userData['username']?.toString() ?? '',
      email: userData['email']?.toString() ?? '',
      token: json['token']?.toString() ?? userData['token']?.toString() ?? '',
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String baseUrl = 'http://192.168.1.7:5289/api/user';
  User? _currentUser;
  final StreamController<User?> _userController = StreamController.broadcast();

  Stream<User?> get userStream => _userController.stream;
  User? get currentUser => _currentUser;

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    print('Token đã được lưu: $token'); // ✅ Kiểm tra token
  }

  // Đăng nhập
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUser = User.fromJson(userData);

        // Lưu token và user info vào SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _currentUser!.token);
        await prefs.setString('user_id', _currentUser!.id);
        await prefs.setString('username', _currentUser!.username);
        await prefs.setString('email', _currentUser!.email);

        _userController.add(_currentUser);
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Đăng ký
  Future<bool> register(String username, String email, String password) async {
    try {
      print('Sending register request with: $username, $email'); // Debug log

      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      print('Register response status: ${response.statusCode}'); // Debug log
      print('Register response body: ${response.body}'); // Debug log

      // Check for successful status codes (both 200 and 201)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final userData = json.decode(response.body);
        print('Parsed user data: $userData'); // Debug log

        try {
          _currentUser = User.fromJson(userData);
          _userController.add(_currentUser);
          return true;
        } catch (e) {
          print('Error parsing user data: $e'); // Debug log
          return false;
        }
      }
      
      print('Registration failed with status: ${response.statusCode}'); // Debug log
      return false;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  // Lấy thông tin profile
  Future<User?> getProfile() async {
    if (_currentUser == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer ${_currentUser!.token}',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      print('Get profile error: $e');
      return null;
    }
  }

  Future<void> loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final id = prefs.getString('user_id');
    final username = prefs.getString('username');
    final email = prefs.getString('email');

    if (token != null && id != null && username != null && email != null) {
      _currentUser = User(id: id, username: username, email: email, token: token);
      _userController.add(_currentUser);
    }
  }

  void logout() async {
    _currentUser = null;
    _userController.add(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('email');
  }
}
