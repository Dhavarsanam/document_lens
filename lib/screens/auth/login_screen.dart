import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/providers/auth_provider.dart';
import 'package:document_lens/core/theme/app_theme.dart';

/// User login screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.loading;
    final showError = authProvider.status == AuthStatus.error;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Center(
                    child: _logo(const [AppTheme.primaryBlue, AppTheme.accentCyan],
                        Icons.document_scanner_rounded)),
                const SizedBox(height: 24),
                const Center(
                  child: Text('Welcome Back!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Sign in to DOCMIND',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14)),
                ),
                const SizedBox(height: 36),
                authLabel('Email'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: authInputDecoration(
                      hint: 'Enter your email',
                      icon: Icons.email_outlined,
                      accent: AppTheme.primaryBlue),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Email is required';
                    if (!val.contains('@')) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                authLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: authInputDecoration(
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    accent: AppTheme.primaryBlue,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white54,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Password is required';
                    if (val.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (showError) authErrorBox(authProvider.errorMessage),
                const SizedBox(height: 28),
                _primaryButton(
                  label: 'Sign In',
                  color: AppTheme.primaryBlue,
                  isLoading: isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== Shared helpers =====================

Widget _logo(List<Color> colors, IconData icon) {
  return Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: 0.4),
          blurRadius: 20,
          spreadRadius: 3,
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: 42),
  );
}

Widget _primaryButton({
  required String label,
  required Color color,
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: isLoading
          ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            color: Colors.white, strokeWidth: 2),
      )
          : Text(label,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}

Widget authLabel(String text) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.8),
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  );
}

Widget authErrorBox(String message) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(color: Colors.red, fontSize: 13)),
        ),
      ],
    ),
  );
}

InputDecoration authInputDecoration({
  required String hint,
  required IconData icon,
  required Color accent,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
    prefixIcon: Icon(icon, color: Colors.white54, size: 20),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: accent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );
}