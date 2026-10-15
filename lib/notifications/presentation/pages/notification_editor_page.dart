import 'dart:async';
import 'package:autth_injustice_app/core/network/pending_sync_dialog.dart';

import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/validation/external_url.dart';
import 'package:autth_injustice_app/core/widgets/editor/app_editor_error_banner.dart';
import 'package:autth_injustice_app/core/widgets/editor/app_editor_step_scaffold.dart';
import 'package:autth_injustice_app/core/widgets/editor/app_editor_text_field.dart';
import 'package:autth_injustice_app/core/widgets/animations/app_step_entrance_transition.dart';
import 'package:autth_injustice_app/core/widgets/dialogs/app_confirmation_dialog.dart';
import 'package:autth_injustice_app/notifications/domain/models/notification_announcement_draft.dart';
import 'package:autth_injustice_app/notifications/domain/models/notification_announcement_validator.dart';
import 'package:autth_injustice_app/notifications/presentation/viewmodels/notification_editor/notification_editor_viewmodel.dart';
import 'package:autth_injustice_app/notifications/presentation/widgets/notification_editor/notification_announcement_review.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

class NotificationEditorPage extends StatefulWidget {
  const NotificationEditorPage({super.key});

  @override
  State<NotificationEditorPage> createState() => _NotificationEditorPageState();
}

class _NotificationEditorPageState extends State<NotificationEditorPage> {
  static const _stepCount = 3;

  late final PageController _pageController;
  late final NotificationEditorViewModel _viewModel;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _externalUrlController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  int _currentStep = 0;
  bool _returnToReview = false;
  String? _validationErrorKey;
  Timer? _validationErrorTimer;

  NotificationAnnouncementDraft get _draft => _viewModel.state.draft.value;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<NotificationEditorViewModel>();
    _viewModel.commands.resetForSession();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _viewModel.commands.resetForSession();
    _validationErrorTimer?.cancel();
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _externalUrlController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _updateDraft(NotificationAnnouncementDraft draft) {
    _viewModel.state.updateDraft(draft);
    if (_validationErrorKey != null) {
      _validationErrorTimer?.cancel();
      setState(() => _validationErrorKey = null);
    } else {
      setState(() {});
    }
  }

  void _showTemporaryValidationError(String key) {
    _validationErrorTimer?.cancel();
    setState(() => _validationErrorKey = key);
    _validationErrorTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _validationErrorKey != key) return;
      setState(() => _validationErrorKey = null);
    });
  }

  String? _validateStep(int step) {
    final issue = switch (step) {
      0 => NotificationAnnouncementValidator.validateTitle(_draft) ??
          NotificationAnnouncementValidator.validateMessage(_draft),
      1 => NotificationAnnouncementValidator.validateExternalLink(_draft),
      2 => NotificationAnnouncementValidator.validateForPublishing(_draft),
      _ => null,
    };
    return issue?.messageKey;
  }

  Future<void> _nextStep() async {
    FocusScope.of(context).unfocus();

    final error = _validateStep(_currentStep);
    if (error != null) {
      _showTemporaryValidationError(error);
      return;
    }

    _validationErrorTimer?.cancel();
    setState(() => _validationErrorKey = null);

    if (_currentStep == _stepCount - 1) {
      final published = await _viewModel.commands.publishAnnouncement();
      if (!mounted || !published) return;
      if (_viewModel.state.errorMessage.value == 'networkWritePending') {
        await showPendingSyncDialog(context);
        if (!mounted) return;
      }
      context.pop(true);
      return;
    }

    if (_returnToReview) {
      _returnToReview = false;
      await _goToStep(_stepCount - 1);
      return;
    }

    await _pageController.nextPage(
      duration: AppStepTransitionSpec.pageDuration,
      curve: AppStepTransitionSpec.pageCurve,
    );
  }

  Future<void> _previousStep() async {
    FocusScope.of(context).unfocus();
    _viewModel.state.clearError();
    _validationErrorTimer?.cancel();
    setState(() => _validationErrorKey = null);

    if (_returnToReview) {
      _returnToReview = false;
      await _goToStep(_stepCount - 1);
      return;
    }

    if (_currentStep == 0) {
      await _closeEditor();
      return;
    }

    await _pageController.previousPage(
      duration: AppStepTransitionSpec.pageDuration,
      curve: AppStepTransitionSpec.pageCurve,
    );
  }

  Future<void> _goToStep(int step) async {
    FocusScope.of(context).unfocus();
    _viewModel.state.clearError();
    _validationErrorTimer?.cancel();
    setState(() => _validationErrorKey = null);
    await _pageController.animateToPage(
      step,
      duration: AppStepTransitionSpec.pageDuration,
      curve: AppStepTransitionSpec.pageCurve,
    );
  }

  void _editReviewStep(int step) {
    _returnToReview = true;
    unawaited(_goToStep(step));
  }

  Future<void> _closeEditor() async {
    if (!_hasContent) {
      if (mounted) context.pop(false);
      return;
    }

    final discard = await showAppConfirmationDialog(
      context: context,
      icon: Icons.edit_off_outlined,
      iconColor: context.colors.error,
      title: context.l10n.notificationEditorDiscardTitle,
      message: context.l10n.notificationEditorDiscardMessage,
      cancelLabel: context.l10n.notificationEditorKeepEditing,
      cancelColor: context.onTertiary.withValues(alpha: 0.62),
      confirmLabel: context.l10n.notificationEditorDiscard,
      confirmColor: context.colors.error,
      confirmForegroundColor: context.colors.onError,
      confirmIcon: Icons.delete_outline_rounded,
    );

    if (discard && mounted) context.pop(false);
  }

  bool get _hasContent =>
      _draft.title.trim().isNotEmpty ||
      _draft.message.trim().isNotEmpty ||
      (_draft.externalUrl?.trim().isNotEmpty ?? false);

  String _stepButtonText(BuildContext context, String defaultText) {
    return _returnToReview
        ? context.l10n.notificationEditorBackToReview
        : defaultText;
  }

  String? _localizedError(BuildContext context, String? key) {
    return switch (key) {
      'networkWriteUnconfirmed' => context.l10n.networkWriteUnconfirmed,
      'networkWritePending' => context.l10n.networkWritePending,
      'notificationEditorInvalidTitle' =>
        context.l10n.notificationEditorInvalidTitle,
      'notificationEditorInvalidDescription' =>
        context.l10n.notificationEditorInvalidDescription,
      'notificationEditorInvalidExternalLink' =>
        context.l10n.notificationEditorInvalidExternalLink,
      'notificationEditorRequiredFields' =>
        context.l10n.notificationEditorRequiredFields,
      'notificationManagementUnauthorized' =>
        context.l10n.notificationManagementUnauthorized,
      null => null,
      _ => context.l10n.notificationEditorPublishError,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_previousStep());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: context.tertiary,
        body: Watch(
          (_) {
            final loading = _viewModel.state.loading.value;
            final commandError = _viewModel.state.errorMessage.value;
            final error = _localizedError(
              context,
              _validationErrorKey ?? commandError,
            );

            return PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                _viewModel.state.setCurrentStep(index);
                _validationErrorTimer?.cancel();
                setState(() {
                  _currentStep = index;
                  _validationErrorKey = null;
                });
              },
              children: [
                AppEditorStepScaffold(
                  active: _currentStep == 0,
                  step: 0,
                  stepCount: _stepCount,
                  title: context.l10n.notificationEditorContentTitle,
                  subtitle: context.l10n.notificationEditorContentSubtitle,
                  buttonText: _stepButtonText(
                    context,
                    context.l10n.continueButton,
                  ),
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    children: [
                      AppEditorTextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        label: context.l10n.notificationEditorTitleLabel,
                        maxLength: NotificationAnnouncementRules.titleMaxLength,
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          _updateDraft(_draft.copyWith(title: value));
                        },
                        onSubmitted: (_) {
                          _descriptionFocusNode.requestFocus();
                        },
                      ),
                      AppEditorErrorBanner(
                        message: _validationErrorKey ==
                                'notificationEditorInvalidTitle'
                            ? error
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppEditorTextField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        label: context.l10n.notificationEditorDescriptionLabel,
                        maxLines: 7,
                        maxLength:
                            NotificationAnnouncementRules.messageMaxLength,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: (value) {
                          _updateDraft(_draft.copyWith(message: value));
                        },
                      ),
                      AppEditorErrorBanner(
                        message: _validationErrorKey ==
                                'notificationEditorInvalidDescription'
                            ? error
                            : null,
                      ),
                    ],
                  ),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 1,
                  step: 1,
                  stepCount: _stepCount,
                  title: context.l10n.notificationEditorLinkTitle,
                  subtitle: context.l10n.notificationEditorLinkSubtitle,
                  buttonText: _stepButtonText(
                    context,
                    context.l10n.notificationEditorReview,
                  ),
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    children: [
                      AppEditorTextField(
                        controller: _externalUrlController,
                        label: context.l10n.notificationEditorLinkLabel,
                        hintText: context.l10n.notificationEditorLinkHint,
                        maxLength: ExternalUrl.maxLength,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: (value) {
                          _updateDraft(
                            _draft.copyWith(
                              externalUrl: value.trim().isEmpty ? null : value,
                            ),
                          );
                        },
                        onSubmitted: (_) => _nextStep(),
                      ),
                      AppEditorErrorBanner(message: error),
                    ],
                  ),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 2,
                  step: 2,
                  stepCount: _stepCount,
                  title: context.l10n.notificationEditorReviewTitle,
                  subtitle: context.l10n.notificationEditorReviewSubtitle,
                  buttonText: context.l10n.notificationEditorPublish,
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NotificationAnnouncementReview(
                        draft: _draft,
                        onEditStep: _editReviewStep,
                      ),
                      AppEditorErrorBanner(message: error),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
