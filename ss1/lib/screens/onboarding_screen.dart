// SafarSathi — Onboarding Screen (login/register)

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool   _isLogin   = true;
  bool   _loading   = false; 
  String _error     = '';

  final _phone    = TextEditingController();
  final _password = TextEditingController();
  final _name     = TextEditingController();

  Future<void> _submit() async {
    setState(() { _loading = true; _error = ''; });
    try {
      if (_isLogin) {
        await api.login(phone: _phone.text.trim(), password: _password.text);
      } else {
        await api.register(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );
      }
      if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  } catch (e) {
    // FIXED: Changed print to debugPrint to satisfy avoid_print lint
    debugPrint("AUTH ERROR: $e"); 
    
    if (context.mounted) {
      setState(() { 
        _error = 'Check your credentials and try again.'; 
      });
    }
  }
    if (context.mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final colors = theme.extension<SafarSathiColors>()!;

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark 
              ? [const Color(0xFF2C1B18), const Color(0xFF0F172A)]
              : [const Color(0xFFFFE0D2), const Color(0xFFE2E8F0)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          // ADDED SingleChildScrollView to prevent the RenderFlex overflow error
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(_isLogin ? 'Welcome\nback' : 'Create\naccount',
                    style: theme.textTheme.displayLarge),
                  const SizedBox(height: 8),
                  Text('SafarSathi — Your safe journey companion',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    )),
                  const SizedBox(height: 32),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                if (!_isLogin) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (+91...)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),

                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_error, style: TextStyle(color: colors.dangerColor, fontSize: 13)),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: SafarSathiTheme.brandSaffron,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(_isLogin ? 'Sign In' : 'Create Account',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin
                        ? "Don't have an account? Sign up"
                        : 'Already have an account? Sign in',
                      style: const TextStyle(color: SafarSathiTheme.brandSaffron),
                    ),
                  ),
                ),
              ],
            ),
          ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}