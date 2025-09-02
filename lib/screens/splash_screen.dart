import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _disposed = false;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndRoute();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _initializeAndRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // If Firebase.initializeApp() is in main(), we can just wait a tick here.
      // If not, move Firebase.initializeApp() to main() and keep Splash lean.
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _disposed) return;
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        if (!mounted || _disposed) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        if (!mounted || _disposed) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (!mounted || _disposed) return;
      setState(() {
        _errorMessage = 'Initialization failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.blue,
        child: Center(
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo.png', width: 120, height: 120),
                    const SizedBox(height: 20),
                    const Text(
                      'Mobile Car Spa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 60),
                    const SizedBox(height: 20),
                    Text(
                      _errorMessage ?? 'Unknown error',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _initializeAndRoute,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
