import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/global_error_handler.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/auth_repository.dart';

enum _AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      if (_mode == _AuthMode.signIn) {
        await repo.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
      } else {
        await repo.signUpWithEmail(
          email: _email.text,
          password: _password.text,
          fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
      }
      if (mounted) context.go('/');
    } on Exception catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _submitting = true);
    final repo = ref.read(authRepositoryProvider);
    if (repo is GuestAuthSupport) {
      await (repo as GuestAuthSupport).continueAsGuest();
    }
    if (mounted) context.go('/');
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDemo = !AppConfig.hasSupabase;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.account_balance_rounded,
                        size: 44, color: scheme.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppConfig.appName,
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppConfig.tagline,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    SegmentedButton<_AuthMode>(
                      segments: const [
                        ButtonSegment(
                          value: _AuthMode.signIn,
                          label: Text('Sign in'),
                        ),
                        ButtonSegment(
                          value: _AuthMode.signUp,
                          label: Text('Create account'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) {
                        setState(() {
                          _mode = s.first;
                          _error = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_mode == _AuthMode.signUp) ...[
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) {
                        if (v == null || !v.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'At least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: AppTypography.bodySmall
                            .copyWith(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_mode == _AuthMode.signIn
                              ? 'Sign in'
                              : 'Create account'),
                    ),
                    if (isDemo) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Demo build — no account needed. '
                        'Email verification is enforced when Supabase is configured.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton(
                        onPressed: _submitting ? null : _continueAsGuest,
                        child: const Text('Continue as guest'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


