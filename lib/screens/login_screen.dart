import 'package:flutter/material.dart';
import '../main.dart';
import 'upload_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    const validUsername = 'admin';
    const validPassword = 'password';
    if (_usernameController.text.trim() == validUsername &&
        _passwordController.text == validPassword) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UploadScreen()),
      );
    } else {
      setState(() => _errorMessage = 'Invalid username or password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E3A5F)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
              ),
            ),
          ),

          // Theme toggle — top right
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) => IconButton(
                  icon: Icon(
                    mode == ThemeMode.dark
                        ? Icons.light_mode
                        : Icons.dark_mode,
                    color: isDark ? Colors.white70 : const Color(0xFF1E3A5F),
                  ),
                  onPressed: () => themeNotifier.value =
                      mode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                ),
              ),
            ),
          ),

          // Centered card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Audio Uploader',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 32),

                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) =>
                              setState(() => _errorMessage = null),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon:
                                const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          onChanged: (_) =>
                              setState(() => _errorMessage = null),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color:
                                  Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      Colors.red.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(_errorMessage!,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _login,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
