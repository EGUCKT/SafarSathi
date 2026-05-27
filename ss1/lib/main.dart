import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'services/guardian_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/profile_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Request critical permissions for Guardian SOS feature
  await [
    Permission.location,
    Permission.locationAlways,
    Permission.sms,
    Permission.phone,
    Permission.notification,
  ].request();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase optional — app works without it
  }

  try {
    await initGuardianService();
  } catch (_) {}

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SafarSathi',
      debugShowCheckedModeBanner: false,
      theme:     SafarSathiTheme.light(),
      darkTheme: SafarSathiTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':     return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/onboarding': return MaterialPageRoute(builder: (_) => const OnboardingScreen());
          case '/home':       return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/map':        return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/sos':        return MaterialPageRoute(builder: (_) => const SosScreen());
          case '/profile':    return CupertinoPageRoute(builder: (_) => const ProfileScreen()); // Fast Slide Transition
          default:            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
      },
    );
  }
}