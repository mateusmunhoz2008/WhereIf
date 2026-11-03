import 'package:autth_injustice_app/authentication/presentation/widgets/feedback/auth_error_banner.dart';
import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/settings/presentation/viewmodels/delete_account/delete_account_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

Future<bool> showDeleteAccountDialog(
  BuildContext context, {
  required bool requiresPassword,
}) async {
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteAccountDialog(requiresPassword: requiresPassword),
  );
  return deleted ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  final bool requiresPassword;

  const _DeleteAccountDialog({required this.requiresPassword});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  late final DeleteAccountViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<DeleteAccountViewModel>();
    _viewModel.state.reset();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (widget.requiresPassword && _passwordController.text.isEmpty) {
      _viewModel.state.setError('accountCurrentPasswordRequired');
      return;
    }

    final deleted = await _viewModel.commands.deleteAccount(
      currentPassword: widget.requiresPassword ? _passwordController.text : null,
    );
    if (deleted && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final error = context.colors.error;

    return Watch((_) {
      final loading = _viewModel.state.loading.value;

      return AlertDialog(
        title: Text(context.l10n.accountDeleteTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.accountDeleteMessage),
              if (widget.requiresPassword) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !loading,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _confirm(),
                  decoration: InputDecoration(
                    labelText: context.l10n.accountCurrentPassword,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AuthErrorBanner(error: _viewModel.state.errorMessage.readonly()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: loading ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: error,
              foregroundColor: context.colors.onError,
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonDelete),
          ),
        ],
      );
    });
  }
}