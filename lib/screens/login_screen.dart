import 'package:flutter/material.dart';
import 'package:smart_kuhlschrank/services/auth_service.dart';
import 'package:smart_kuhlschrank/l10n/app_localizations.dart'; // Import the l10n library

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isLogin = true; // Toggle between Login and Register

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context)!;
    final validEmail = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(email);

    if (!validEmail) {
      _showMessage(l10n.authInvalidEmail, isError: true);
      return;
    }
    if (!_isLogin && password.length < 8) {
      _showMessage(l10n.authWeakPassword, isError: true);
      return;
    }

    setState(() => _isLoading = true);
    String? message;
    var isError = false;

    try {
      if (_isLogin) {
        await _authService.signIn(email, password);
      } else {
        await _authService.signUp(email, password);
        message = l10n.registrationEmailSent;
        _passwordController.clear();
        _isLogin = true;
      }
    } on AuthServiceException catch (error) {
      message = _messageForFailure(error.code, l10n);
      isError = true;
    } catch (_) {
      message = l10n.authUnknownError;
      isError = true;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (message != null) _showMessage(message, isError: isError);
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  String _messageForFailure(
    AuthFailureCode code,
    AppLocalizations l10n,
  ) {
    return switch (code) {
      AuthFailureCode.invalidCredentials => l10n.authInvalidCredentials,
      AuthFailureCode.invalidEmail => l10n.authInvalidEmail,
      AuthFailureCode.weakPassword => l10n.authWeakPassword,
      AuthFailureCode.registrationUnavailable =>
        l10n.authRegistrationUnavailable,
      AuthFailureCode.verificationRequired => l10n.authVerificationRequired,
      AuthFailureCode.tooManyRequests => l10n.authTooManyRequests,
      AuthFailureCode.network => l10n.authNetworkError,
      AuthFailureCode.unknown => l10n.authUnknownError,
    };
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.inventory_2,
                size: 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                _isLogin ? l10n.login : l10n.register,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 254,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                autofillHints: _isLogin
                    ? const [AutofillHints.password]
                    : const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 128,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(_isLogin ? l10n.login : l10n.register),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(_isLogin
                    ? l10n.dontHaveAccount
                    : l10n.alreadyHaveAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
