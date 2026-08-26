import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/core/theme/app_theme.dart';
import 'package:document_lens/providers/auth_provider.dart';
import 'package:document_lens/services/settings_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Shown when App Lock is enabled and biometric auth has failed/been
  // cancelled, so the user can retry without being logged out.
  bool _showUnlockRetry = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), _proceed);
  }

  Future<void> _proceed() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();

    if (!authProvider.isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (SettingsService.appLockEnabled) {
      final unlocked = await _tryUnlock();
      if (!mounted) return;
      if (!unlocked) {
        setState(() => _showUnlockRetry = true);
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/main');
  }

  Future<bool> _tryUnlock() async {
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
      if (!canCheck) return true; // no biometric available, don't block

      return await localAuth.authenticate(
        localizedReason: 'Unlock DOCMIND',
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _showUnlockRetry
                        ? Icons.lock_rounded
                        : Icons.document_scanner_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'DOCMIND',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _showUnlockRetry
                      ? 'App is locked'
                      : 'Scan. Extract. Digitize.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                    letterSpacing: 1.2,
                  ),
                ),
                if (_showUnlockRetry) ...[
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => _showUnlockRetry = false);
                      await _proceed();
                    },
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Unlock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}