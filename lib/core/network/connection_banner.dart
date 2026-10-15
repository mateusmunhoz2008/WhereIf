import 'package:flutter/material.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'network_status.dart';
import 'queued_write.dart';

class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key, required this.child});
  final Widget child;
  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner>
    with WidgetsBindingObserver {
  bool _hidden = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NetworkStatus.instance.addListener(_changed);
    QueuedWrite.lateFailure.addListener(_changed);
    NetworkStatus.instance.start();
  }

  void _changed() {
    if (NetworkStatus.instance.value == true) _hidden = false;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NetworkStatus.instance.start();
    } else {
      NetworkStatus.instance.stop();
    }
  }

  @override
  void dispose() {
    NetworkStatus.instance.removeListener(_changed);
    QueuedWrite.lateFailure.removeListener(_changed);
    NetworkStatus.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if ((!_hidden && NetworkStatus.instance.value == false) ||
            QueuedWrite.lateFailure.value)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Dismissible(
              key: const ValueKey('connection-warning'),
              direction: DismissDirection.horizontal,
              onDismissed: (_) => setState(() {
                _hidden = true;
                QueuedWrite.lateFailure.value = false;
              }),
              child: Material(
                elevation: 4,
                color: Theme.of(context).colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Icon(Icons.cloud_off_outlined,
                          color:
                              Theme.of(context).colorScheme.onInverseSurface),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              QueuedWrite.lateFailure.value
                                  ? context.l10n.networkSyncFailed
                                  : context.l10n.connectionUnavailable,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onInverseSurface,
                                  fontSize: 12))),
                    ])),
              ),
            ),
          ),
      ]);
}
