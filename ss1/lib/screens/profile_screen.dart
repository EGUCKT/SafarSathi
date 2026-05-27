// SafarSathi — Profile Screen

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<dynamic> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final c = await api.getContacts();
      if (mounted) setState(() { _contacts = c; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addContact() async {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl   = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Emergency Contact'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number (+91...)')),
          TextField(controller: relCtrl,
              decoration: const InputDecoration(labelText: 'Relation (e.g. Mother)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: SafarSathiTheme.brandSaffron),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await api.addContact(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  relation: relCtrl.text.trim(),
                );
                _loadContacts();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'),
                        behavior: SnackBarBehavior.floating));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final colors  = Theme.of(context).extension<SafarSathiColors>()!;

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
        appBar: AppBar(
          title: const Text('Profile & Safety'),
          backgroundColor: Colors.transparent,
          actions: [
            TextButton(
              onPressed: () async {
    await api.logout();
    
    // Use context.mounted instead of just mounted
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  },
              child: Text('Sign out',
                  style: TextStyle(color: colors.dangerColor)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
        children: [

          // ── Emergency contacts ──────────────────────────────────────────
          Text('Emergency Contacts',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'These contacts will receive an emergency SMS with your live location when SOS triggers.',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            ..._contacts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: SafarSathiTheme.brandSaffron.withAlpha(31),
                  child: Text(
                    (c['name'] as String? ?? '?').isNotEmpty
                        ? (c['name'] as String).substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: SafarSathiTheme.brandSaffron,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  Text(
                    '${c['phone'] ?? ''}  ·  ${c['relation'] ?? ''}',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ])),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: colors.dangerColor, size: 20),
                  onPressed: () async {
                    await api.deleteContact(c['id']);
                    _loadContacts();
                  },
                ),
              ]),
            ))),

            if (_contacts.length < 3) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _addContact,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_rounded,
                        color: SafarSathiTheme.brandSaffron, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add contact (${3 - _contacts.length} of 3 remaining)',
                      style: const TextStyle(
                          color: SafarSathiTheme.brandSaffron,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),
              ),
            ],
          ],

          const SizedBox(height: 32),

          // ── SOS trigger info ────────────────────────────────────────────
          Text('SOS Trigger Methods',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _TriggerTile(
            icon: Icons.volume_up_rounded,
            title: 'Scream for help',
            subtitle: 'If you are in danger during the journey, Scream for help.',
            color: const Color(0xFF007AFF),
          ),
          const SizedBox(height: 8),
          _TriggerTile(
            icon: Icons.touch_app_rounded,
            title: 'Hold SOS button (3 sec)',
            subtitle: 'Press and hold the red SOS button in the dock',
            color: const Color(0xFFFF3B30),
          ),

          const SizedBox(height: 32),

          // ── App info ────────────────────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('About SafarSathi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              Text(
                'SafarSathi is a safety navigation app for women and vulnerable groups. '
                'Currently focused on Mhow and Indore. Built with AI-driven risk analysis.',
                style: TextStyle(fontSize: 13, color: colors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text('v1.0.0 - Fantastic Four',
                  style: TextStyle(fontSize: 11, color: colors.textMuted)),
            ]),
          ),

          const SizedBox(height: 40),
        ],
      ),
    ),
    );
  }
}

class _TriggerTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  const _TriggerTile({required this.icon, required this.title,
      required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withAlpha(31),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          Text(subtitle,
              style: TextStyle(fontSize: 12,
                  color: Theme.of(context).extension<SafarSathiColors>()!.textMuted)),
        ])),
      ]),
      ),
    );
  }
}