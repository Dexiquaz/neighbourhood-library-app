import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;

  Future<void> _signup() async {
    setState(() => _loading = true);

    try {
      // 1️⃣ Create auth user
      await _auth.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2️⃣ Get the newly created user
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('User not created');
      }

      // 3️⃣ Create profile row (CRITICAL)
      await Supabase.instance.client.from('profiles').insert({
        'id': user.id,
        'name': _emailController.text.split('@')[0], // temp name
        'latitude': 0.0, // GPS later
        'longitude': 0.0, // GPS later
        'locality': 'Unknown',
      });

      if (!mounted) return;

      // 4️⃣ Go back to login page
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signup,
                    child: const Text("Sign Up"),
                  ),
          ],
        ),
      ),
    );
  }
}
