import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/habit.dart';
import '../services/habit_repository.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/icon_registry.dart';
import '../widgets/color_picker.dart';
import '../widgets/font_picker.dart';
import '../widgets/habit_card.dart';
import '../widgets/icon_picker.dart';

const List<String> _weekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const Map<String, int> _fontWeightOptions = {
  'Light': 2,
  'Regular': 3,
  'Medium': 4,
  'Bold': 6,
};

class AddHabitScreen extends StatefulWidget {
  /// Null = create a new habit.
  /// Existing habit = edit that habit.
  final Habit? habit;

  const AddHabitScreen({
    super.key,
    this.habit,
  });

  bool get isEditing => habit != null;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  int _currentStep = 0;
  static const int _totalSteps = 7;

  final _nameController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _targetUnitController = TextEditingController();
  final _customScheduleController = TextEditingController();
  // Text edits refresh only the live card, not the entire seven-step form.
  final ValueNotifier<int> _previewRevision = ValueNotifier<int>(0);

  String? _iconKey;
  int _colorValue = AppColors.aqua.toARGB32();
  AppFontFamily _fontFamily = AppFontFamily.modernSans;
  int _fontWeightIndex = 3;
  bool _isItalic = false;

  GoalType _goalType = GoalType.simpleCompletion;

  FrequencyType _frequencyType = FrequencyType.daily;
  final Set<int> _selectedDays = {};

  bool _reminderEnabled = false;
  final List<String> _reminderTimes = [];

  @override
  void initState() {
    super.initState();
    _loadExistingHabit();
  }

  void _loadExistingHabit() {
    final habit = widget.habit;

    if (habit == null) return;

    _nameController.text = habit.name;
    _targetValueController.text =
        habit.targetValue?.toString() ?? '';
    _targetUnitController.text =
        habit.targetUnit ?? '';
    _customScheduleController.text =
        habit.customSchedule ?? '';

    _iconKey = habit.iconKey;
    _colorValue = habit.colorValue;

    _fontFamily = AppFontFamily.values.firstWhere(
      (family) => family.name == habit.fontFamilyKey,
      orElse: () => AppFontFamily.modernSans,
    );

    // Normalize legacy SemiBold (index 5) to Medium now that SemiBold is
    // no longer offered in the picker.
    _fontWeightIndex = habit.fontWeightIndex == 5 ? 4 : habit.fontWeightIndex;
    _isItalic = habit.isItalic;

    _goalType = habit.goalType;
    _frequencyType = habit.frequencyType;

    _selectedDays
      ..clear()
      ..addAll(habit.selectedDays);

    _reminderEnabled = habit.reminderEnabled;

    _reminderTimes
      ..clear()
      ..addAll(habit.reminderTimes)
      ..sort();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetValueController.dispose();
    _targetUnitController.dispose();
    _customScheduleController.dispose();
    _previewRevision.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.habit != null;

  Color get _accentColor => Color(_colorValue);

  Habit _buildDraftHabit() {
    final isMeasurable =
        _goalType == GoalType.count ||
        _goalType == GoalType.duration;

    return Habit(
      id: _isEditing ? widget.habit!.id : 'draft',
      name: _nameController.text.trim().isEmpty
          ? 'New Habit'
          : _nameController.text.trim(),
      iconKey: _iconKey ?? 'star',
      colorValue: _colorValue,
      fontFamilyKey: _fontFamily.name,
      fontWeightIndex: _fontWeightIndex,
      isItalic: _isItalic,
      goalType: _goalType,
      targetValue: isMeasurable
          ? (double.tryParse(
                _targetValueController.text.trim(),
              ) ??
              (_goalType == GoalType.duration ? 60 : 8))
          : null,
      targetUnit: isMeasurable
          ? (_goalType == GoalType.duration
              ? 'minutes'
              : (_targetUnitController.text.trim().isEmpty
                  ? 'times'
                  : _targetUnitController.text.trim()))
          : null,
      frequencyType: _frequencyType,
      selectedDays: _frequencyType == FrequencyType.specificDays
          ? (_selectedDays.toList()..sort())
          : [],
      customSchedule: _frequencyType == FrequencyType.custom
          ? _customScheduleController.text.trim()
          : null,
      reminderEnabled: _reminderEnabled,
      reminderTimes:
          _reminderEnabled ? List.of(_reminderTimes) : [],
      createdAt:
          _isEditing ? widget.habit!.createdAt : DateTime.now(),
      completionHistory:
          _isEditing ? List.of(widget.habit!.completionHistory) : [],
    );
  }

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          return 'Please enter a habit name.';
        }
        return null;

      case 1:
        if (_iconKey == null) {
          return 'Please choose an icon.';
        }
        return null;

      case 2:
        return null;

      case 3:
        if (_goalType == GoalType.count ||
            _goalType == GoalType.duration) {
          final value = double.tryParse(
            _targetValueController.text.trim(),
          );

          if (value == null || value <= 0) {
            return 'Please enter a valid goal amount.';
          }
        }
        return null;

      case 4:
        if (_frequencyType == FrequencyType.specificDays &&
            _selectedDays.isEmpty) {
          return 'Select at least one day.';
        }

        if (_frequencyType == FrequencyType.custom &&
            _customScheduleController.text.trim().isEmpty) {
          return 'Describe your custom schedule.';
        }

        return null;

      case 5:
        if (_reminderEnabled && _reminderTimes.isEmpty) {
          return 'Add a reminder time, or turn reminders off.';
        }
        return null;

      default:
        return null;
    }
  }

  void _onStepContinue() {
    final error = _validateStep(_currentStep);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (_currentStep == _totalSteps - 1) {
      _saveHabit();
    } else {
      setState(() => _currentStep += 1);
    }
  }

  void _onStepCancel() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _saveHabit() async {
    final isMeasurable =
        _goalType == GoalType.count ||
        _goalType == GoalType.duration;

    final existingHabit = widget.habit;

    final habit = Habit(
      id: existingHabit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      iconKey: _iconKey!,
      colorValue: _colorValue,
      fontFamilyKey: _fontFamily.name,
      fontWeightIndex: _fontWeightIndex,
      isItalic: _isItalic,
      goalType: _goalType,
      targetValue: isMeasurable
          ? double.tryParse(
              _targetValueController.text.trim(),
            )
          : null,
      targetUnit: isMeasurable
          ? (_goalType == GoalType.duration
              ? 'minutes'
              : (_targetUnitController.text.trim().isEmpty
                  ? 'times'
                  : _targetUnitController.text.trim()))
          : null,
      frequencyType: _frequencyType,
      selectedDays: _frequencyType == FrequencyType.specificDays
          ? (_selectedDays.toList()..sort())
          : [],
      customSchedule: _frequencyType == FrequencyType.custom
          ? _customScheduleController.text.trim()
          : null,
      reminderEnabled: _reminderEnabled,
      reminderTimes:
          _reminderEnabled ? List.of(_reminderTimes) : [],
      createdAt: existingHabit?.createdAt,
      completionHistory:
          existingHabit?.completionHistory == null
              ? []
              : List.of(existingHabit!.completionHistory),
    );

    final repository = context.read<HabitRepository>();

    if (_isEditing) {
      await repository.updateHabit(habit);
    } else {
      await repository.addHabit(habit);
    }

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> _confirmDeleteHabit() async {
    final habit = widget.habit;
    if (habit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete this habit?'),
        content: Text(
          'â€œ${habit.name}â€ and its completion history will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<HabitRepository>().deleteHabit(habit.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickReminderTime({
    TimeOfDay? initialTime,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.aqua,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    if (_reminderTimes.contains(formatted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That reminder time is already added.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _reminderTimes.add(formatted);
      _reminderTimes.sort();
    });
  }

  void _addQuickReminder(int hour, int minute) {
    final formatted =
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';

    if (_reminderTimes.contains(formatted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That reminder time is already added.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _reminderTimes.add(formatted);
      _reminderTimes.sort();
    });
  }

  String _formatReminderTime(String time) {
    final parts = time.split(':');

    if (parts.length != 2) {
      return time;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return time;
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour =
        hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Edit Habit' : 'New Habit',
        ),
        actions: _isEditing
            ? [
                IconButton(
                  tooltip: 'Delete habit',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _confirmDeleteHabit,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: _previewRevision,
                builder: (context, _, __) =>
                    _LivePreview(habit: _buildDraftHabit()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: Colors.transparent,
                  ),
                  child: Stepper(
                    type: StepperType.vertical,
                    currentStep: _currentStep,
                    onStepContinue: _onStepContinue,
                    onStepCancel: _onStepCancel,
                    controlsBuilder: (context, details) {
                      final isLast =
                          _currentStep == _totalSteps - 1;

                      return Padding(
                        padding: const EdgeInsets.only(
                          top: 20,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    details.onStepCancel,
                                style:
                                    OutlinedButton.styleFrom(
                                  foregroundColor:
                                      AppColors.textSecondary,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  _currentStep == 0
                                      ? 'Cancel'
                                      : 'Back',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed:
                                    details.onStepContinue,
                                child: Text(
                                  isLast
                                      ? (_isEditing
                                          ? 'Save Changes'
                                          : 'Create Habit')
                                      : 'Continue',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      Step(
                        title:
                            const Text('Basic Information'),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepBasicInfo(),
                      ),
                      Step(
                        title: const Text('Icon'),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepIcon(),
                      ),
                      Step(
                        title: const Text('Appearance'),
                        isActive: _currentStep >= 2,
                        state: _currentStep > 2
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepAppearance(),
                      ),
                      Step(
                        title: const Text('Goal'),
                        isActive: _currentStep >= 3,
                        state: _currentStep > 3
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepGoal(),
                      ),
                      Step(
                        title: const Text('Schedule'),
                        isActive: _currentStep >= 4,
                        state: _currentStep > 4
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepFrequency(),
                      ),
                      Step(
                        title: const Text('Reminders'),
                        isActive: _currentStep >= 5,
                        state: _currentStep > 5
                            ? StepState.complete
                            : StepState.indexed,
                        content: _stepReminders(),
                      ),
                      Step(
                        title:
                            const Text('Preview & Confirm'),
                        isActive: _currentStep >= 6,
                        state: StepState.indexed,
                        content: _stepConfirmation(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What do you want to track?',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          autofocus: !_isEditing,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          onChanged: (_) => _previewRevision.value++,
          decoration: InputDecoration(
            hintText:
                'e.g. Hydration, Coding, Reading',
            hintStyle: const TextStyle(
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.surfaceHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepIcon() {
    return IconPicker(
      selectedKey: _iconKey,
      accentColor: _accentColor,
      onSelected: (key) => setState(
        () => _iconKey = key,
      ),
    );
  }

  Widget _stepAppearance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Color'),
        const SizedBox(height: 10),
        ColorPicker(
          selectedColor: _accentColor,
          onSelected: (color) => setState(
            () => _colorValue = color.toARGB32(),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Font'),
        const SizedBox(height: 10),
        FontPicker(
          selectedFamily: _fontFamily,
          accentColor: _accentColor,
          onSelected: (family) => setState(
            () => _fontFamily = family,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Weight'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _fontWeightOptions.entries.map((entry) {
            return _OptionChip(
              label: entry.key,
              selected:
                  _fontWeightIndex == entry.value,
              color: _accentColor,
              onTap: () => setState(
                () => _fontWeightIndex = entry.value,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Italic style',
                style: TextStyle(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Switch(
              value: _isItalic,
              onChanged: (v) => setState(
                () => _isItalic = v,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepGoal() {
    final isMeasurable =
        _goalType == GoalType.count ||
        _goalType == GoalType.duration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Goal Type'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: GoalType.values.map((type) {
            return _OptionChip(
              label: type.label,
              selected: _goalType == type,
              color: _accentColor,
              onTap: () => setState(
                () => _goalType = type,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        if (_goalType == GoalType.simpleCompletion)
          const _InfoNote(
            'This habit is marked complete or not â€” '
            'no numbers needed.',
          ),
        if (_goalType == GoalType.custom)
          const _InfoNote(
            'No fixed target. You can log progress freely '
            'whenever you like.',
          ),
        if (isMeasurable) ...[
          TextField(
            controller: _targetValueController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _previewRevision.value++,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: _goalType == GoalType.duration
                  ? 'Target minutes (e.g. 120)'
                  : 'Target amount (e.g. 8)',
              labelStyle: const TextStyle(
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_goalType == GoalType.count) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _targetUnitController,
              onChanged: (_) => _previewRevision.value++,
              style: const TextStyle(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText:
                    'Unit (e.g. glasses, pages)',
                labelStyle: const TextStyle(
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _stepFrequency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Frequency'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FrequencyType.values.map((type) {
            return _OptionChip(
              label: type.label,
              selected: _frequencyType == type,
              color: _accentColor,
              onTap: () => setState(
                () => _frequencyType = type,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        if (_frequencyType ==
            FrequencyType.specificDays) ...[
          const _SectionLabel('Days'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final weekday = i + 1;
              final selected =
                  _selectedDays.contains(weekday);

              return _OptionChip(
                label: _weekdayLabels[i],
                selected: selected,
                color: _accentColor,
                onTap: () => setState(() {
                  if (selected) {
                    _selectedDays.remove(weekday);
                  } else {
                    _selectedDays.add(weekday);
                  }
                }),
              );
            }),
          ),
        ],
        if (_frequencyType == FrequencyType.custom) ...[
          TextField(
            controller: _customScheduleController,
            onChanged: (_) => _previewRevision.value++,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  'e.g. Every other day, twice a week',
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _InfoNote(
            'This is a description of your routine. It appears on the habit card and in the confirmation summary; CANOPY does not calculate reminder days from this text. If reminders are enabled, the times you choose repeat daily. Choose Specific days for weekday-specific reminders.',
          ),
        ],
        if (_frequencyType ==
            FrequencyType.noFixedFrequency)
          const _InfoNote(
            'No completion days are enforced. If you enable reminders, the times you choose repeat daily as gentle nudges.',
          ),
      ],
    );
  }

  Widget _stepReminders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _reminderEnabled
                  ? _accentColor.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: _accentColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remind me',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get a gentle nudge when it is time for this habit.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _reminderEnabled,
                onChanged: (v) async {
                  if (v) {
                    final granted =
                        await NotificationService()
                            .requestNotificationPermission();

                    await NotificationService()
                        .requestExactAlarmPermission();

                    if (!mounted) return;

                    if (!granted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Notification permission is required for reminders.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (!SettingsService()
                        .remindersEnabled) {
                      await SettingsService()
                          .setRemindersEnabled(true);
                    }
                  }

                  if (!mounted) return;

                  setState(() {
                    _reminderEnabled = v;
                  });
                },
              ),
            ],
          ),
        ),
        if (_reminderEnabled) ...[
          const SizedBox(height: 22),
          const _SectionLabel('Quick times'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ReminderPreset(
                icon: Icons.wb_sunny_outlined,
                label: 'Morning',
                time: '8:00 AM',
                selected:
                    _reminderTimes.contains('08:00'),
                color: _accentColor,
                onTap: () =>
                    _addQuickReminder(8, 0),
              ),
              _ReminderPreset(
                icon: Icons.light_mode_outlined,
                label: 'Afternoon',
                time: '1:00 PM',
                selected:
                    _reminderTimes.contains('13:00'),
                color: _accentColor,
                onTap: () =>
                    _addQuickReminder(13, 0),
              ),
              _ReminderPreset(
                icon: Icons.wb_twilight,
                label: 'Evening',
                time: '6:00 PM',
                selected:
                    _reminderTimes.contains('18:00'),
                color: _accentColor,
                onTap: () =>
                    _addQuickReminder(18, 0),
              ),
              _ReminderPreset(
                icon: Icons.nightlight_outlined,
                label: 'Night',
                time: '9:00 PM',
                selected:
                    _reminderTimes.contains('21:00'),
                color: _accentColor,
                onTap: () =>
                    _addQuickReminder(21, 0),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Custom time'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickReminderTime,
              icon: Icon(
                Icons.add_alarm_rounded,
                color: _accentColor,
              ),
              label: Text(
                'Choose another time',
                style: TextStyle(
                  color: _accentColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color:
                      _accentColor.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_reminderTimes.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel('Your reminders'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: _reminderTimes.map((time) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.alarm_rounded,
                      color: _accentColor,
                      size: 21,
                    ),
                    title: Text(
                      _formatReminderTime(time),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove reminder',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textTertiary,
                        size: 19,
                      ),
                      onPressed: () {
                        setState(() {
                          _reminderTimes.remove(time);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _InfoNote(
            _reminderScheduleDescription(),
          ),
        ] else ...[
          const SizedBox(height: 12),
          const _InfoNote(
            'Reminders are optional. You can turn them on '
            'whenever you want a nudge for this habit.',
          ),
        ],
      ],
    );
  }

  String _reminderScheduleDescription() {
    switch (_frequencyType) {
      case FrequencyType.daily:
        return 'You will be reminded every day at your selected times.';

      case FrequencyType.specificDays:
        if (_selectedDays.isEmpty) {
          return 'Choose your schedule above to decide which days reminders are sent.';
        }

        final sortedDays = _selectedDays.toList()..sort();

        final days = sortedDays
            .map((d) => _weekdayLabels[d - 1])
            .join(', ');

        return 'You will be reminded on $days at your selected times.';

      case FrequencyType.custom:
        return 'Your custom schedule is descriptive text only. Reminder times repeat daily; CANOPY does not infer days from the text.';

      case FrequencyType.noFixedFrequency:
        return 'No completion schedule is enforced. If enabled, reminders repeat daily at your selected times.';
    }
  }

  Widget _stepConfirmation() {
    final habit = _buildDraftHabit();

    final colorName = AppColors.habitPalette.firstWhere(
      (o) => o.color.toARGB32() == _colorValue,
      orElse: () => const HabitColorOption(
        'Custom',
        Colors.white,
      ),
    ).name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Summary'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _summaryRow('Name', habit.name),
              _summaryRow(
                'Icon',
                IconRegistry.labelFor(habit.iconKey),
              ),
              _summaryRow('Color', colorName),
              _summaryRow(
                'Font',
                AppFonts.labelFor(_fontFamily),
              ),
              _summaryRow(
                'Goal',
                _goalSummary(),
              ),
              _summaryRow(
                'Frequency',
                _frequencySummary(),
              ),
              _summaryRow(
                'Reminders',
                _reminderSummary(),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoNote(
          _isEditing
              ? 'Your existing progress and streak history will be preserved.'
              : 'This habit starts with no history â€” tracking begins today.',
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _goalSummary() {
    switch (_goalType) {
      case GoalType.simpleCompletion:
        return 'Simple completion';

      case GoalType.count:
        final v = _targetValueController.text.trim();

        final unit =
            _targetUnitController.text.trim().isEmpty
                ? 'times'
                : _targetUnitController.text.trim();

        return v.isEmpty ? 'Count' : '$v $unit';

      case GoalType.duration:
        final v = _targetValueController.text.trim();

        return v.isEmpty ? 'Duration' : '$v minutes';

      case GoalType.custom:
        return 'Flexible / no fixed target';
    }
  }

  String _frequencySummary() {
    switch (_frequencyType) {
      case FrequencyType.daily:
        return 'Every day';

      case FrequencyType.specificDays:
        if (_selectedDays.isEmpty) {
          return 'Specific days';
        }

        final sorted = _selectedDays.toList()..sort();

        return sorted
            .map((d) => _weekdayLabels[d - 1])
            .join(', ');

      case FrequencyType.custom:
        final text =
            _customScheduleController.text.trim();

        return text.isEmpty
            ? 'Custom schedule'
            : text;

      case FrequencyType.noFixedFrequency:
        return 'No fixed frequency';
    }
  }

  String _reminderSummary() {
    if (!_reminderEnabled ||
        _reminderTimes.isEmpty) {
      return 'Off';
    }

    return _reminderTimes
        .map(_formatReminderTime)
        .join(', ');
  }
}

class _LivePreview extends StatelessWidget {
  final Habit habit;

  const _LivePreview({
    required this.habit,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: HabitCard(
        key: ValueKey(
          '${habit.name}-${habit.colorValue}-'
          '${habit.iconKey}-'
          '${habit.fontFamilyKey}-'
          '${habit.fontWeightIndex}-'
          '${habit.isItalic}-${habit.goalType}',
        ),
        habit: habit,
        onIncrement: () {},
        onDecrement: () {},
        onToggleComplete: () {},
        onTap: () {},
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;

  const _InfoNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _ReminderPreset extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ReminderPreset({
    required this.icon,
    required this.label,
    required this.time,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 132,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? color
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected
                  ? color
                  : AppColors.textSecondary,
              size: 21,
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? color
                    : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? color
                : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
