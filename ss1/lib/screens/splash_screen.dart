import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Remove the native splash screen as soon as this Flutter screen draws its first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _navigate();
  }

  Future<void> _navigate() async {
    // Fast animation delay before routing
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;

    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      token != null ? '/home' : '/onboarding',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark 
                ? [const Color(0xFF2C1B18), const Color(0xFF0F172A)]
                : [const Color(0xFFFFE0D2), const Color(0xFFE2E8F0)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: SafarSathiTheme.brandSaffron.withOpacity(isDark ? 0.2 : 0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text(
                  'SS',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    color: SafarSathiTheme.brandSaffron,
                  ),
                ),
              ),
            ).animate()
             .scale(duration: 800.ms, curve: Curves.easeOutBack)
             .fadeIn(duration: 600.ms)
             .shimmer(delay: 800.ms, duration: 1200.ms, color: Colors.white.withOpacity(0.5)),

            const SizedBox(height: 40),

            // Liquid Glass App Name Badge
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.15 : 0.6),
                        (isDark ? const Color(0xFF1C1C1E) : Colors.white).withOpacity(isDark ? 0.4 : 0.3),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SafarSathi',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your safe journey companion',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate()
             .slideY(begin: 1.0, end: 0, duration: 200.ms, curve: Curves.easeOutCubic, delay: 300.ms)
             .fadeIn(duration: 200.ms, delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
