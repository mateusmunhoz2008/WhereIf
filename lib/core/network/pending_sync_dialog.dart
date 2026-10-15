import 'package:flutter/material.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';

Future<void> showPendingSyncDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.networkWritePendingTitle),
        content: Text(context.l10n.networkWritePending),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).okButtonLabel))
        ],
      ),
    );
