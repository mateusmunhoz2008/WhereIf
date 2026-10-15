import 'dart:async';
import 'package:autth_injustice_app/core/network/pending_sync_dialog.dart';

import 'package:autth_injustice_app/core/di/dependency_injection.dart';
import 'package:autth_injustice_app/core/l10n/l10n_extensions.dart';
import 'package:autth_injustice_app/core/theme/app_theme.dart';
import 'package:autth_injustice_app/core/widgets/app_status_view.dart';
import 'package:autth_injustice_app/core/widgets/animations/app_step_entrance_transition.dart';
import 'package:autth_injustice_app/core/widgets/dialogs/app_confirmation_dialog.dart';
import 'package:autth_injustice_app/core/widgets/editor/app_editor_error_banner.dart';
import 'package:autth_injustice_app/core/widgets/editor/app_editor_step_scaffold.dart';
import 'package:autth_injustice_app/core/widgets/editor/app_editor_text_field.dart';
import 'package:autth_injustice_app/core/widgets/pickers/app_date_time_picker.dart';
import 'package:autth_injustice_app/core/widgets/pickers/app_date_time_fields.dart';
import 'package:autth_injustice_app/events/domain/models/event_draft_validator.dart';
import 'package:autth_injustice_app/events/domain/models/event_editor_draft.dart';
import 'package:autth_injustice_app/events/domain/models/event_timing.dart';
import 'package:autth_injustice_app/events/presentation/viewmodels/event_editor/event_editor_viewmodel.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_editor/event_category_selector.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_editor/event_map_location_selector.dart';
import 'package:autth_injustice_app/events/presentation/widgets/event_editor/event_editor_sections.dart';
import 'package:autth_injustice_app/institution/presentation/institution_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signals_flutter/signals_flutter.dart';

class EventEditorPage extends StatefulWidget {
  final String? eventId;

  const EventEditorPage({
    super.key,
    this.eventId,
  });

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  static const _stepCount = 8;

  late final PageController _pageController;
  final _imagePicker = ImagePicker();

  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _externalUrlController = TextEditingController();

  late final EventEditorViewModel _viewModel;

  int _currentStep = 0;
  bool _ready = false;
  bool _returnToReview = false;
  bool _hasUnsavedChanges = false;
  String? _validationErrorKey;
  Timer? _validationErrorTimer;

  EventEditorDraft get _draft => _viewModel.state.draft.value;
  bool get _isEditing => widget.eventId != null;

  @override
  void initState() {
    super.initState();
    _viewModel = injector.get<EventEditorViewModel>();
    _viewModel.commands.resetForSession();
    _currentStep = _isEditing ? _stepCount - 1 : 0;
    _pageController = PageController(initialPage: _currentStep);
    _ready = !_isEditing;

    if (_isEditing) {
      unawaited(_loadEventForEditing());
    } else {
      unawaited(_recoverLostImage());
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _validationErrorTimer?.cancel();
    _pageController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _externalUrlController.dispose();
    super.dispose();
  }

  void _updateDraft(EventEditorDraft draft) {
    _viewModel.state.updateDraft(draft);
    _hasUnsavedChanges = true;
    _onDraftChanged();
  }

  void _mutateDraft(VoidCallback mutation) {
    mutation();
    _hasUnsavedChanges = true;
    _onDraftChanged();
  }

  Future<void> _loadEventForEditing() async {
    final loaded = await _viewModel.commands.loadEventForEditing(
      widget.eventId!,
    );
    if (!mounted) return;

    if (loaded) {
      _titleController.text = _draft.title;
      _locationController.text = _draft.location ?? '';
      _descriptionController.text = _draft.description;
      _externalUrlController.text = _draft.externalUrl ?? '';
      _hasUnsavedChanges = false;
      setState(() => _ready = true);
      unawaited(_recoverLostImage());
      return;
    }

    setState(() => _ready = false);
  }

  void _onDraftChanged() {
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

  Future<void> _recoverLostImage() async {
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty || !mounted) return;

      final files = response.files;
      if (files != null && files.isNotEmpty) {
        _updateDraft(
          _draft.copyWith(selectedImageSource: files.first.path),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _validationErrorKey = 'eventEditorImageError');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
      if (image == null || !mounted) return;

      _updateDraft(_draft.copyWith(selectedImageSource: image.path));
    } catch (_) {
      if (mounted) {
        setState(() => _validationErrorKey = 'eventEditorImageError');
      }
    }
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final current = _draft.startsAt;
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate =
        current != null && !current.isBefore(firstDate) ? current : firstDate;
    final selected = await AppDateTimePicker.pickDate(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5),
    );
    if (selected == null || !mounted) return;

    final defaultTime = TimeOfDay.fromDateTime(
      now.add(const Duration(hours: 1)),
    );
    final time = current == null || !current.isAfter(now)
        ? defaultTime
        : TimeOfDay.fromDateTime(current);
    _updateEventStart(_combineDateAndTime(selected, time));
  }

  Future<void> _pickEventTime() async {
    if (_draft.startsAt == null) {
      await _pickEventDate();
      if (_draft.startsAt == null || !mounted) return;
    }

    final selected = await AppDateTimePicker.pickTime(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_draft.startsAt!),
    );
    if (selected == null || !mounted) return;

    _updateEventStart(_combineDateAndTime(_draft.startsAt!, selected));
  }

  void _updateEventStart(DateTime startsAt) {
    _mutateDraft(
      () => _viewModel.state.updateEventStart(startsAt),
    );
  }

  void _setEndMode(EventEndMode mode) {
    _mutateDraft(
      () => _viewModel.state.setEndMode(mode),
    );
  }

  Future<void> _pickEndDate() async {
    final startsAt = _draft.startsAt!;
    final current = _draft.endsAt ?? startsAt.add(const Duration(hours: 2));
    final selected = await AppDateTimePicker.pickDate(
      context: context,
      initialDate: current,
      firstDate: DateTime(startsAt.year, startsAt.month, startsAt.day),
      lastDate: startsAt.add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) return;

    _updateDraft(
      _draft.copyWith(
        endsAt: _combineDateAndTime(
          selected,
          TimeOfDay.fromDateTime(current),
        ),
      ),
    );
  }

  Future<void> _pickEndTime() async {
    final startsAt = _draft.startsAt!;
    final current = _draft.endsAt ?? startsAt.add(const Duration(hours: 2));
    final selected = await AppDateTimePicker.pickTime(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selected == null || !mounted) return;

    _updateDraft(
      _draft.copyWith(
        endsAt: _combineDateAndTime(current, selected),
      ),
    );
  }

  void _setPublicationMode(EventPublicationMode mode) {
    _mutateDraft(
      () => _viewModel.state.setPublicationMode(
        mode,
        now: DateTime.now(),
      ),
    );
  }

  Future<void> _pickPublicationDate() async {
    final now = DateTime.now();
    final eventAt = _draft.startsAt!;
    final current = _draft.publishAt ?? now;
    final selected = await AppDateTimePicker.pickDate(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(eventAt.year, eventAt.month, eventAt.day),
    );
    if (selected == null || !mounted) return;

    final time = TimeOfDay.fromDateTime(current);
    _updateDraft(
      _draft.copyWith(publishAt: _combineDateAndTime(selected, time)),
    );
  }

  Future<void> _pickPublicationTime() async {
    final current = _draft.publishAt ?? DateTime.now();
    final selected = await AppDateTimePicker.pickTime(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selected == null || !mounted) return;

    _updateDraft(
      _draft.copyWith(
        publishAt: _combineDateAndTime(current, selected),
      ),
    );
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  void _setHoursEnabled(bool value) {
    _mutateDraft(
      () => _viewModel.state.setComplementaryHoursEnabled(value),
    );
  }

  void _setHours(int value) {
    _mutateDraft(
      () => _viewModel.state.setComplementaryHours(value),
    );
  }

  void _setMinutes(int value) {
    _mutateDraft(
      () => _viewModel.state.setComplementaryMinutes(value),
    );
  }

  String? _validateStep(int step) {
    final now = DateTime.now();
    final issue = switch (step) {
      0 => EventDraftValidator.validateIdentity(_draft),
      1 => _isEditing
          ? EventDraftValidator.validateStartForUpdate(_draft)
          : EventDraftValidator.validateStart(_draft, now: now),
      2 => EventDraftValidator.validateEnd(_draft),
      3 => EventDraftValidator.validateLocation(_draft),
      4 => EventDraftValidator.validateDescription(_draft),
      5 => EventDraftValidator.validateComplementaryHours(_draft),
      6 => EventDraftValidator.validateImage(_draft),
      7 => EventDraftValidator.validatePublication(_draft, now: now),
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
      final saved = _isEditing
          ? await _viewModel.commands.updateEvent()
          : await _viewModel.commands.createEvent();
      if (!mounted || !saved) return;
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

    if (_isEditing && _currentStep == _stepCount - 1) {
      await _closeEditor();
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
    final shouldConfirm = _isEditing ? _hasUnsavedChanges : _hasContent;
    if (!shouldConfirm) {
      if (mounted) context.pop(false);
      return;
    }

    final discard = await showAppConfirmationDialog(
      context: context,
      icon: Icons.edit_off_outlined,
      iconColor: context.colors.error,
      title: _isEditing
          ? context.l10n.eventEditorDiscardChangesTitle
          : context.l10n.eventEditorDiscardTitle,
      message: _isEditing
          ? context.l10n.eventEditorDiscardChangesMessage
          : context.l10n.eventEditorDiscardMessage,
      cancelLabel: context.l10n.eventEditorKeepEditing,
      cancelColor: context.onTertiary.withValues(alpha: 0.72),
      confirmLabel: context.l10n.eventEditorDiscard,
      confirmColor: context.colors.error,
      confirmForegroundColor: context.colors.onError,
      confirmIcon: Icons.delete_sweep_outlined,
    );

    if (discard && mounted) context.pop(false);
  }

  bool get _hasContent =>
      _draft.title.trim().isNotEmpty ||
      _draft.category != null ||
      _draft.startsAt != null ||
      _draft.endMode != null ||
      _draft.location != null ||
      _draft.mapLocations.isNotEmpty ||
      _draft.description.trim().isNotEmpty ||
      (_draft.externalUrl?.trim().isNotEmpty ?? false) ||
      _draft.complementaryMinutes != null ||
      _draft.selectedImageSource != null ||
      _draft.publishAt != null;

  String _stepButtonText(BuildContext context, String defaultText) {
    return _returnToReview ? context.l10n.eventEditorBackToReview : defaultText;
  }

  String? _localizedError(BuildContext context, String? key) {
    return switch (key) {
      'networkWriteUnconfirmed' => context.l10n.networkWriteUnconfirmed,
      'networkWritePending' => context.l10n.networkWritePending,
      'eventEditorInvalidTitle' => context.l10n.eventEditorInvalidTitle,
      'eventEditorInvalidCategory' => context.l10n.eventEditorInvalidCategory,
      'eventEditorMissingDate' => context.l10n.eventEditorMissingDate,
      'eventEditorFutureDate' => context.l10n.eventEditorFutureDate,
      'eventEditorMissingEndMode' => context.l10n.eventEditorMissingEndMode,
      'eventEditorEndAfterStart' => context.l10n.eventEditorEndAfterStart,
      'eventEditorInvalidLocation' => context.l10n.eventEditorInvalidLocation,
      'eventEditorInvalidDescription' =>
        context.l10n.eventEditorInvalidDescription,
      'eventEditorInvalidExternalLink' =>
        context.l10n.eventEditorInvalidExternalLink,
      'eventEditorInvalidHours' => context.l10n.eventEditorInvalidHours,
      'eventEditorMissingImage' => context.l10n.eventEditorMissingImage,
      'eventEditorImageError' => context.l10n.eventEditorImageError,
      'eventEditorFuturePublication' =>
        context.l10n.eventEditorFuturePublication,
      'eventEditorPublishBeforeEvent' =>
        context.l10n.eventEditorPublishBeforeEvent,
      'eventEditorRequiredFields' => context.l10n.eventEditorRequiredFields,
      'eventManagementUnauthorized' => context.l10n.eventManagementUnauthorized,
      null => null,
      _ => _isEditing
          ? context.l10n.eventEditorUpdateError
          : context.l10n.eventEditorCreateError,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: context.tertiary,
        body: SafeArea(
          child: Watch(
            (_) {
              if (_viewModel.state.loading.value) {
                return const AppStatusView.loading();
              }

              return AppStatusView(
                icon: Icons.event_busy_outlined,
                message: context.l10n.eventEditorLoadError,
                actionLabel: context.l10n.eventEditorTryAgain,
                onAction: () => unawaited(_loadEventForEditing()),
              );
            },
          ),
        ),
      );
    }

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
                  title: context.l10n.eventEditorIdentityTitle,
                  subtitle: context.l10n.eventEditorIdentitySubtitle,
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
                        label: context.l10n.eventEditorTitle,
                        maxLength: 80,
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          _updateDraft(_draft.copyWith(title: value));
                        },
                        onSubmitted: (_) => _nextStep(),
                      ),
                      AppEditorErrorBanner(
                        message:
                            _validationErrorKey == 'eventEditorInvalidTitle'
                                ? error
                                : null,
                      ),
                      const SizedBox(height: 16),
                      EventCategorySelector(
                        selectedCategory: _draft.category,
                        onSelected: (category) {
                          FocusScope.of(context).unfocus();
                          _updateDraft(_draft.copyWith(category: category));
                        },
                      ),
                      AppEditorErrorBanner(
                        message:
                            _validationErrorKey == 'eventEditorInvalidCategory'
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
                  title: context.l10n.eventEditorDateTitle,
                  subtitle: context.l10n.eventEditorDateSubtitle,
                  buttonText: _stepButtonText(
                    context,
                    context.l10n.continueButton,
                  ),
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    children: [
                      AppDateTimeFields(
                        value: _draft.startsAt,
                        dateLabel: context.l10n.eventEditorDate,
                        timeLabel: context.l10n.eventEditorTime,
                        emptyDateText: context.l10n.eventEditorChooseDate,
                        emptyTimeText: context.l10n.eventEditorChooseTime,
                        onPickDate: _pickEventDate,
                        onPickTime: _pickEventTime,
                      ),
                      AppEditorErrorBanner(message: error),
                    ],
                  ),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 2,
                  step: 2,
                  stepCount: _stepCount,
                  title: context.l10n.eventEditorEndTitle,
                  subtitle: context.l10n.eventEditorEndSubtitle,
                  buttonText: _stepButtonText(
                    context,
                    context.l10n.continueButton,
                  ),
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    children: [
                      EventEndSelector(
                        mode: _draft.endMode,
                        endsAt: _draft.endsAt,
                        onModeChanged: _setEndMode,
                        onPickDate: _pickEndDate,
                        onPickTime: _pickEndTime,
                      ),
                      AppEditorErrorBanner(message: error),
                    ],
                  ),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 3,
                  step: 3,
                  stepCount: _stepCount,
                  title: context.l10n.eventEditorLocationTitle,
                  subtitle: context.l10n.eventEditorLocationSubtitle,
                  buttonText: _stepButtonText(
                    context,
                    context.l10n.continueButton,
                  ),
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EventMapLocationSelector(
                            selected: _draft.mapLocations,
                            onChanged: (locations) {
                              _locationController.clear();
                              _updateDraft(_draft.copyWith(
                                  mapLocations: locations, location: null));
                            }),
                        if (_draft.mapLocations.isEmpty) ...[
                          const SizedBox(height: 20),
                          AppEditorTextField(
                            controller: _locationController,
                            label: context.l10n.eventLocationOutsideMap,
                            maxLength: EventDraftRules.locationMaxLength,
                            textInputAction: TextInputAction.done,
                            onChanged: (value) {
                              final location =
                                  value.trim().isEmpty ? null : value;
                              _updateDraft(_draft.copyWith(location: location));
                            },
                            onSubmitted: (_) => _nextStep(),
                          ),
                        ],
                      ]),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 4,
                  step: 4,
                  stepCount: _stepCount,
                  title: context.l10n.eventEditorDescriptionTitle,
                  subtitle: context.l10n.eventEditorDescriptionSubtitle,
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
                        controller: _descriptionController,
                        label: context.l10n.eventEditorDescription,
                        maxLines: 7,
                        maxLength: 1000,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        onChanged: (value) {
                          _updateDraft(_draft.copyWith(description: value));
                        },
                      ),
                      if (context.institution.events.allowExternalLinks) ...[
                        const SizedBox(height: 16),
                        AppEditorTextField(
                          controller: _externalUrlController,
                          label: context.l10n.eventEditorExternalLink,
                          hintText: context.l10n.eventEditorExternalLinkHint,
                          maxLength: 500,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: (value) {
                            _updateDraft(
                              _draft.copyWith(
                                externalUrl:
                                    value.trim().isEmpty ? null : value,
                              ),
                            );
                          },
                          onSubmitted: (_) => _nextStep(),
                        ),
                      ],
                      AppEditorErrorBanner(message: error),
                    ],
                  ),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 5,
                  step: 5,
                  stepCount: _stepCount,
                  title: context.l10n.eventEditorHoursTitle,
                  subtitle: context.l10n.eventEditorHoursSubtitle,
                  buttonText: _stepButtonText(
                    context,
                    context.l10n.continueButton,
                  ),
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    children: [
                      EventHoursSelector(
                        enabled: _viewModel.state.hasComplementaryHours,
                        hours: _viewModel.state.complementaryHours,
                        minutes: _viewModel.state.complementaryMinutes,
                        onEnabledChanged: _setHoursEnabled,
                        onHoursChanged: _setHours,
                        onMinutesChanged: _setMinutes,
                      ),
                      AppEditorErrorBanner(message: error),
                    ],
                  ),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 6,
                  step: 6,
                  stepCount: _stepCount,
                  title: context.l10n.eventEditorImageTitle,
                  subtitle: context.l10n.eventEditorImageSubtitle,
                  buttonText: _stepButtonText(
                    context,
                    context.l10n.eventEditorReview,
                  ),
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    children: [
                      EventImageSelector(
                        draft: _draft,
                        onPickImage: _pickImage,
                        onSelectPreset: (image) {
                          _updateDraft(
                            _draft.copyWith(
                              selectedImageSource: image.location,
                            ),
                          );
                        },
                      ),
                      AppEditorErrorBanner(message: error),
                    ],
                  ),
                ),
                AppEditorStepScaffold(
                  active: _currentStep == 7,
                  step: 7,
                  stepCount: _stepCount,
                  title: _isEditing
                      ? context.l10n.eventEditorEditReviewTitle
                      : context.l10n.eventEditorReviewTitle,
                  subtitle: _isEditing
                      ? context.l10n.eventEditorEditReviewSubtitle
                      : context.l10n.eventEditorReviewSubtitle,
                  buttonText: _isEditing
                      ? context.l10n.eventEditorSaveChanges
                      : _viewModel.state.publicationMode ==
                              EventPublicationMode.now
                          ? context.l10n.eventEditorPublish
                          : context.l10n.eventEditorScheduleEvent,
                  loading: loading,
                  onBack: _previousStep,
                  onNext: _nextStep,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EventReviewSummary(
                        draft: _draft,
                        onEditStep: _editReviewStep,
                      ),
                      if (!_isEditing || _draft.publishAt != null) ...[
                        const SizedBox(height: 28),
                        EventPublicationSelector(
                          mode: _viewModel.state.publicationMode,
                          publishAt: _draft.publishAt,
                          onModeChanged: _setPublicationMode,
                          onPickDate: _pickPublicationDate,
                          onPickTime: _pickPublicationTime,
                        ),
                      ],
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
