import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({Key? key}) : super(key: key);

  @override
  State<SplashLoginScreen> createState() => _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  late final FirebaseAuth _auth;
  late final Stream<User?> _authStateChanges;

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _authStateChanges = _auth.authStateChanges();
    _listenAuthAndNavigate();

    // Clear stale error when user edits
    emailCtrl.addListener(_clearErrorOnInput);
    passwordCtrl.addListener(_clearErrorOnInput);
  }

  void _clearErrorOnInput() {
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
  }

  void _listenAuthAndNavigate() {
    _authStateChanges.listen((user) async {
      if (!mounted) return;
      // Small delay to avoid showing transient messages during route change
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
  }

  Future<void> _signIn() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );
      // Do not navigate here; auth listener will handle it.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _errorMessage = 'Invalid email format.';
            break;
          case 'user-disabled':
            _errorMessage = 'This user has been disabled.';
            break;
          case 'user-not-found':
            _errorMessage = 'No user found for that email.';
            break;
          case 'wrong-password':
            _errorMessage = 'Incorrect password.';
            break;
          case 'too-many-requests':
            _errorMessage = 'Too many attempts. Try again later.';
            break;
          default:
            _errorMessage = e.message ?? 'Authentication error.';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    emailCtrl.removeListener(_clearErrorOnInput);
    passwordCtrl.removeListener(_clearErrorOnInput);
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = _loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: AbsorbPointer(
        absorbing: disabled,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (!_loading && _errorMessage != null && _errorMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !disabled,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Enter your email';
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(v)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  enabled: !disabled,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter your password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _signIn,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Login', style: TextStyle(fontSize: 18)),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
