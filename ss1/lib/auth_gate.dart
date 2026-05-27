import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

/// Authentication gateway that routes users based on login state.
/// Shows LoginScreen if not authenticated, HomeScreen if authenticated.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          developer.log('User authenticated: ${snapshot.data!.uid}', name: 'SafarSathi.Auth');
          return const HomeScreen();
        }

        // User is not logged in
        developer.log('User not authenticated', name: 'SafarSathi.Auth');
        return const LoginScreen();
      },
    );
  }
}

/// Simple login UI for anonymous and credential-based authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInAnonymously() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      developer.log('Signing in anonymously...', name: 'SafarSathi.Auth');
      await FirebaseAuth.instance.signInAnonymously();
      developer.log('Anonymous sign-in successful', name: 'SafarSathi.Auth');
    } catch (e) {
      developer.log('Anonymous sign-in error: $e', name: 'SafarSathi.Auth', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SafarSathi Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security_rounded, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'SafarSathi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Women Safety Guardian',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _buildAnonymousSignInButton(),
              const SizedBox(height: 16),
              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnonymousSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isLoading ? null : _signInAnonymously,
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Continue with Anonymous Account'),
      ),
    );
  }
}