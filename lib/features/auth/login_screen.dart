import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/browser_utils.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';

/// Login screen with Google OAuth (primary) and team email/password sign-in.
///
/// Booth visitors use "Continue with Google" for instant zero-setup access.
/// Team members use email/password credentials to access administrative and
/// predictive fan controls.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // Router redirect fires automatically via authStateProvider.
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('disallowed_useragent')) {
        setState(
          () => _errorMessage = 'Google sign-in is not supported in this browser. Please open this page in Chrome or Safari.',
        );
      } else {
        setState(
          () => _errorMessage = e
              .toString()
              .replaceAll('AuthFailure(', '')
              .replaceAll(')', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitTeamSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      // Router redirect fires automatically via authStateProvider.
    } on AuthFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(
        () => _errorMessage = e
            .toString()
            .replaceAll('AuthFailure(', '')
            .replaceAll(')', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inAppBrowser = kIsWeb && isCurrentBrowserInApp();
    final isNarrow = MediaQuery.sizeOf(context).width < 400;
    final pagePadding = isNarrow ? 16.0 : 24.0;
    final cardPadding = isNarrow ? 16.0 : 24.0;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: pagePadding,
            vertical: 24.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Icon (64 dp, rounded corners)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/icon/icon.png',
                            width: 64,
                            height: 64,
                            semanticLabel: 'AeroSense App Icon',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AeroSense',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Adaptive Ventilation Companion',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Primary Action: Continue with Google
                      FilledButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Image.asset(
                                  'assets/icon/google_logo.png',
                                  fit: BoxFit.contain,
                                  semanticLabel: 'Google icon',
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Continue with Google'),
                            ],
                          ),
                        ),
                      ),

                      // In-app browser detection notice
                      if (inAppBrowser) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Open this page in Chrome or Safari to sign in with Google.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.tierColors.medium,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Divider for secondary Team Sign-in
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or team sign-in',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitTeamSignIn(),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter your password.';
                          }
                          return null;
                        },
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 16),

                      OutlinedButton(
                        onPressed: _isLoading ? null : _submitTeamSignIn,
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : const Text('Sign In as Team'),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                ref
                                    .read(demoModeProvider.notifier)
                                    .setDemo(true);
                              },
                        child: const Text('Try Demo Mode'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
