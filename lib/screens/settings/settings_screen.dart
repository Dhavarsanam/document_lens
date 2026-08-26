import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:document_lens/providers/theme_provider.dart';
import 'package:document_lens/providers/auth_provider.dart';
import 'package:document_lens/core/constants/app_constants.dart';
import 'package:document_lens/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _groqApiKey;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _biometricEnabled = SettingsService.appLockEnabled;
    _groqApiKey = SettingsService.groqApiKey;
  }

  String _maskedGroqKey(String key) {
    if (key.length <= 8) return '•' * key.length;
    return '${key.substring(0, 4)}${'•' * 8}${key.substring(key.length - 4)}';
  }

  void _showGroqKeyDialog(BuildContext context) {
    final controller = TextEditingController(text: _groqApiKey ?? '');
    bool obscure = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Groq API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Used for AI-powered OCR that actually understands the '
                    'language you pick — much more accurate than the '
                    'on-device recognizer, especially for switching '
                    'between languages on the same photo.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'API key',
                  hintText: 'gsk_...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://console.groq.com/keys'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text(
                  'Get a free key at console.groq.com/keys',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          actions: [
            if (_groqApiKey != null && _groqApiKey!.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await SettingsService.clearGroqApiKey();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    setState(() => _groqApiKey = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Groq key removed — using on-device OCR'),
                        backgroundColor: Colors.grey,
                      ),
                    );
                  }
                },
                child:
                const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isEmpty) return;
                await SettingsService.setGroqApiKey(key);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  setState(() => _groqApiKey = key);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Groq API key saved!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkBiometric() async {
    final available = await _localAuth.canCheckBiometrics;
    setState(() => _biometricAvailable = available);
  }

  Future<void> _toggleBiometric() async {
    if (!_biometricEnabled) {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable app lock',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (authenticated) {
        setState(() => _biometricEnabled = true);
        await SettingsService.setAppLockEnabled(true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('App Lock Enabled!'),
                backgroundColor: Colors.green),
          );
        }
      }
    } else {
      setState(() => _biometricEnabled = false);
      await SettingsService.setAppLockEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('App Lock Disabled'),
              backgroundColor: Colors.grey),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final mood = themeProvider.currentMood;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF00BCD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.document_scanner_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(AppConstants.appName,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text('Version ${AppConstants.appVersion}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      if (authProvider.currentUser != null)
                        Text(
                          authProvider.currentUser!.email,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account Section
          const _SectionTitle(title: 'Account'),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.person_outline_rounded,
                  color: Colors.blue),
              title: const Text('Profile',
                  style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text(
                authProvider.currentUser?.name ?? 'User',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showEditProfileDialog(context, authProvider),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ Mood-Based Theme Section
          const _SectionTitle(title: 'Appearance'),

          // Current Mood Card
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mood.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border:
              Border.all(color: mood.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text(mood.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mood.name} Mode',
                        style: TextStyle(
                          color: mood.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        mood.description,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        mood.timeRange,
                        style: TextStyle(
                            fontSize: 11,
                            color: mood.color,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Theme Mode Options
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                _ThemeOptionTile(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Light Mode',
                  color: Colors.orange,
                  isSelected:
                  themeProvider.appThemeMode == AppThemeMode.light,
                  onTap: () =>
                      themeProvider.setThemeMode(AppThemeMode.light),
                ),
                const Divider(height: 1),
                _ThemeOptionTile(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark Mode',
                  color: Colors.indigo,
                  isSelected:
                  themeProvider.appThemeMode == AppThemeMode.dark,
                  onTap: () =>
                      themeProvider.setThemeMode(AppThemeMode.dark),
                ),
                const Divider(height: 1),
                _ThemeOptionTile(
                  icon: Icons.phone_android_rounded,
                  label: 'System Default',
                  color: Colors.grey,
                  isSelected:
                  themeProvider.appThemeMode == AppThemeMode.system,
                  onTap: () =>
                      themeProvider.setThemeMode(AppThemeMode.system),
                ),
                const Divider(height: 1),
                // ✅ Mood Based Theme Option
                _ThemeOptionTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Mood-Based (Auto)',
                  sublabel: 'Changes with time of day',
                  color: Colors.purple,
                  isSelected: themeProvider.appThemeMode ==
                      AppThemeMode.moodBased,
                  onTap: () => themeProvider
                      .setThemeMode(AppThemeMode.moodBased),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ✅ Mood Schedule Preview
          if (themeProvider.appThemeMode == AppThemeMode.moodBased)
            _MoodScheduleCard(),

          const SizedBox(height: 16),

          // Security
          const _SectionTitle(title: 'Security'),
          _SettingsTile(
            icon: Icons.fingerprint_rounded,
            title: 'App Lock',
            subtitle: _biometricAvailable
                ? (_biometricEnabled
                ? 'Enabled'
                : 'Tap to enable biometric lock')
                : 'Biometric not available on this device',
            trailing: _biometricAvailable
                ? Switch(
              value: _biometricEnabled,
              onChanged: (_) => _toggleBiometric(),
              activeColor: Colors.blue,
            )
                : const Icon(Icons.block_rounded, color: Colors.grey),
          ),

          const SizedBox(height: 16),

          // ✅ OCR Engine (Groq AI)
          const _SectionTitle(title: 'OCR Engine'),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                Icons.auto_awesome_rounded,
                color: (_groqApiKey != null && _groqApiKey!.isNotEmpty)
                    ? Colors.deepPurple
                    : Colors.grey,
              ),
              title: const Text('Groq AI OCR',
                  style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: Text(
                (_groqApiKey != null && _groqApiKey!.isNotEmpty)
                    ? 'Active — key ${_maskedGroqKey(_groqApiKey!)}'
                    : 'Not set — using on-device OCR only',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showGroqKeyDialog(context),
            ),
          ),

          const SizedBox(height: 16),

          // About
          const _SectionTitle(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About App',
            subtitle: 'DOCMIND — Intelligent Document Processing',
            onTap: () => _showAboutDialog(context),
          ),
          const _SettingsTile(
            icon: Icons.code_rounded,
            title: 'Technology',
            subtitle: 'Flutter • Google ML Kit • Hive',
          ),
          const _SettingsTile(
            icon: Icons.school_rounded,
            title: 'Project Type',
            subtitle: 'UG Final Year Project',
          ),

          const SizedBox(height: 16),

          // Logout
          const _SectionTitle(title: 'Session'),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading:
              const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                      fontSize: 14)),
              subtitle: const Text('Sign out from your account',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Colors.red),
              onTap: _logout,
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('DOCMIND'),
        content: const Text(
          'A Flutter-based OCR app that extracts text from images using Google ML Kit.\n\n'
              'Features:\n'
              '• Camera & Gallery scan\n'
              '• Multi-language OCR\n'
              '• PDF & TXT export\n'
              '• Document history\n'
              '• Category organization\n'
              '• Mood-Based Theme\n'
              '• Auto File Naming\n'
              '• Insights & Statistics',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
      BuildContext context, AuthProvider authProvider) {
    final nameController =
    TextEditingController(text: authProvider.currentUser?.name ?? '');
    final email = authProvider.currentUser?.email ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              email,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Text(
              'Email cannot be changed',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              final success = await authProvider.updateName(newName);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Profile updated!'
                        : 'Could not update profile'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ✅ Mood Schedule Preview Card
class _MoodScheduleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded,
                  color: Colors.purple, size: 18),
              SizedBox(width: 8),
              Text(
                'Auto Theme Schedule',
                style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ScheduleRow(
              emoji: '☀️',
              time: '6 AM - 12 PM',
              label: 'Morning',
              theme: 'Light Blue',
              color: Colors.blue),
          _ScheduleRow(
              emoji: '🌤️',
              time: '12 PM - 5 PM',
              label: 'Afternoon',
              theme: 'Light Warm',
              color: Colors.orange),
          _ScheduleRow(
              emoji: '🌅',
              time: '5 PM - 8 PM',
              label: 'Evening',
              theme: 'Sunset',
              color: Colors.deepOrange),
          _ScheduleRow(
              emoji: '🌙',
              time: '8 PM - 6 AM',
              label: 'Night',
              theme: 'Dark Blue',
              color: Colors.indigo),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String emoji;
  final String time;
  final String label;
  final String theme;
  final Color color;

  const _ScheduleRow({
    required this.emoji,
    required this.time,
    required this.label,
    required this.theme,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    bool isActive = false;
    if (label == 'Morning' && hour >= 6 && hour < 12) isActive = true;
    if (label == 'Afternoon' && hour >= 12 && hour < 17) isActive = true;
    if (label == 'Evening' && hour >= 17 && hour < 20) isActive = true;
    if (label == 'Night' && (hour >= 20 || hour < 6)) isActive = true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label — $theme',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isActive ? color : null,
                  ),
                ),
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Active',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// Theme Option Tile
class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    this.sublabel,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? color : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: isSelected ? color : null,
        ),
      ),
      subtitle: sublabel != null
          ? Text(sublabel!, style: const TextStyle(fontSize: 11))
          : null,
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: color)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// Section Title
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
              letterSpacing: 0.5)),
    );
  }
}

// Settings Tile
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle:
        Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded)
                : null),
        onTap: onTap,
      ),
    );
  }
}