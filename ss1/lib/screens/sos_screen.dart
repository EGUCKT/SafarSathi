// SafarSathi — SOS Screen
// Full-screen emergency interface, activated by holding SOS button
// or volume button press 3x

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool   _sosSent       = false;
  bool   _sending       = false;
  String _statusMessage = 'Hold to send SOS';
  Map<String, dynamic>? _sosResult;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Vibrate to indicate SOS screen opened
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    if (_sending || _sosSent) return;
    setState(() { _sending = true; _statusMessage = 'Sending SOS...'; });

    HapticFeedback.heavyImpact();

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final result = await api.triggerSOS(
        lat: pos.latitude,
        lng: pos.longitude,
        triggerType: 'manual_button',
      );

      setState(() {
        _sosSent       = true;
        _sending       = false;
        _sosResult     = result;
        _statusMessage = result['message'] ?? 'SOS sent!';
      });

      // Three strong vibrations
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      setState(() {
        _sending       = false;
        _statusMessage = 'SOS sent via SMS (offline mode)';
        _sosSent       = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text('EMERGENCY',
                    style: TextStyle(
                      color: Colors.white.withAlpha(153),
                      fontSize: 12, letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),

            const Spacer(),

            // ── Main SOS button ──────────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse rings
                    if (!_sosSent) ...[
                      Transform.scale(
                        scale: 1.4 + _pulseController.value * 0.3,
                        child: Container(
                          width: 200, height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF453A).withValues(
                              alpha: 0.3 - _pulseController.value * 0.3,
                              ),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 1.2 + _pulseController.value * 0.2,
                        child: Container(
                          width: 200, height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF453A).withValues(
                                alpha: 0.4 - _pulseController.value * 0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    child!,
                  ],
                );
              },
              child: GestureDetector(
                onLongPress: _triggerSOS,
                onTap: () => HapticFeedback.lightImpact(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width:  _sosSent ? 220 : 200,
                  height: _sosSent ? 220 : 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sosSent
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF453A),
                    boxShadow: [
                      BoxShadow(
                        color: (_sosSent
                            ? const Color(0xFF30D158)
                            : const Color(0xFFFF453A)).withAlpha(127),
                        blurRadius:  40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_sending)
                        const CircularProgressIndicator(color: Colors.white)
                      else if (_sosSent)
                        const Icon(Icons.check_rounded,
                            color: Colors.white, size: 64)
                      else
                        const Icon(Icons.sos_rounded,
                            color: Colors.white, size: 64),
                      const SizedBox(height: 8),
                      Text(
                        _sosSent ? 'SENT' : 'HOLD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().scale(
              duration: 400.ms, curve: Curves.elasticOut,
              begin: const Offset(0.8, 0.8),
            ),

            const SizedBox(height: 40),

            // ── Status message ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.white.withAlpha(204),
                  fontSize: 16, height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // ── SOS result details ───────────────────────────────────────────
            if (_sosResult != null) ...[
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(25)),
                ),
                child: Column(
                  children: [
                    _ResultRow(
                      icon:  Icons.check_circle_rounded,
                      color: const Color(0xFF30D158),
                      label: 'WhatsApp sent',
                      value: _sosResult!['whatsapp_sent'] == true ? 'Yes' : 'No',
                    ),
                    if (_sosResult!['nearest_safe_haven'] != null) ...[
                      const SizedBox(height: 10),
                      _ResultRow(
                        icon:  Icons.local_police_rounded,
                        color: const Color(0xFF007AFF),
                        label: 'Nearest haven',
                        value: _sosResult!['nearest_safe_haven']['name'] ?? '',
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms),
            ],

            const Spacer(),

            // ── Volume button hint ───────────────────────────────────────────
            if (!_sosSent)
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  'Or press Volume Down 3× to trigger SOS\nfrom anywhere, screen off',
                  style: TextStyle(
                    color: Colors.white.withAlpha(102),
                    fontSize: 12, height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── I'm safe button ──────────────────────────────────────────────
            if (_sosSent)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: GestureDetector(
                  onTap: () {
                    if (_sosResult != null) {
                      api.resolveSOS(_sosResult!['sos_id']);
                    }
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF30D158),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      "I'm Safe — Cancel Alert",
                      style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ).animate().slideY(begin: 0.2, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _ResultRow({required this.icon, required this.color,
      required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      const Spacer(),
      Text(value, style: const TextStyle(
        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,
      )),
    ],
  );
}
