import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/habit_repository.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';

/// Modal dialog for exporting a complete JSON backup of CANOPY data to the clipboard.
class BackupExportDialog extends StatelessWidget {
  const BackupExportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const BackupExportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitRepo = context.watch<HabitRepository>();
    final settingsService = SettingsService();
    final backupService = BackupService();

    final habits = habitRepo.habits;
    final totalLoggedDays = backupService.getTotalLoggedDays(habits);
    final now = DateTime.now();
    final jsonString = backupService.createBackupJson(
      habits: habits,
      settings: settingsService,
    );

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.aqua.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.backup_outlined, color: AppColors.aqua, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup Data',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Stored locally as structured JSON',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  _StatRow(
                    label: 'Total habits',
                    value: '${habits.length}',
                    icon: Icons.checklist_rounded,
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _StatRow(
                    label: 'Total logged days',
                    value: '$totalLoggedDays',
                    icon: Icons.calendar_today_outlined,
                  ),
                  const Divider(color: AppColors.border, height: 16),
                  _StatRow(
                    label: 'Export date',
                    value: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                    icon: Icons.access_time_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your backup contains your full habit definitions, daily completion history, and personal preferences.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: jsonString));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup JSON copied to clipboard.'),
                            backgroundColor: AppColors.surfaceHigh,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy JSON'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.aqua,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog for validating and restoring a CANOPY JSON backup.
class BackupRestoreDialog extends StatefulWidget {
  const BackupRestoreDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const BackupRestoreDialog(),
    );
  }

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> {
  final TextEditingController _jsonController = TextEditingController();
  final BackupService _backupService = BackupService();
  BackupValidationResult? _validationResult;
  bool _isConfirming = false;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _jsonController.text;
    final result = _backupService.validateBackupJson(text);
    setState(() {
      _validationResult = result;
      _isConfirming = false;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      _jsonController.text = data.text!;
      _validate();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
    }
  }

  Future<void> _executeRestore() async {
    final habitRepo = context.read<HabitRepository>();
    final settings = SettingsService();

    final restoreResult = await _backupService.restoreBackup(
      _jsonController.text,
      habitRepository: habitRepo,
      settingsService: settings,
    );

    if (!mounted) return;

    Navigator.of(context).pop();

    if (restoreResult.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(restoreResult.message),
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: ${restoreResult.message}'),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.oceanBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restore_outlined, color: AppColors.lightBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Restore Data',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Paste your CANOPY JSON backup',
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    'Backup JSON',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste_rounded, size: 14, color: AppColors.aqua),
                    label: const Text(
                      'Paste from Clipboard',
                      style: TextStyle(fontSize: 12, color: AppColors.aqua),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _jsonController,
                maxLines: 5,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '{\n  "schemaVersion": 1,\n  "settings": { ... },\n  "habits": [ ... ]\n}',
                  hintStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.aqua),
                  ),
                ),
                onChanged: (_) => _validate(),
              ),
              const SizedBox(height: 16),
              if (_validationResult != null) ...[
                if (_validationResult!.isValid) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: AppColors.emerald, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Valid Backup File',
                              style: TextStyle(
                                color: AppColors.emerald,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${_validationResult!.habitCount} habits ready to restore\n'
                          '• ${_validationResult!.totalLoggedDays} total completion entries\n'
                          '• Preferences included',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.rose.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validationResult!.error ?? 'Invalid backup format.',
                            style: const TextStyle(
                              color: AppColors.rose,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              if (_validationResult?.isValid == true && _isConfirming) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: Restoring will overwrite all current habits and history with the backup data.',
                          style: TextStyle(
                            color: AppColors.coral,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_validationResult?.isValid != true)
                          ? null
                          : () {
                              if (!_isConfirming) {
                                setState(() => _isConfirming = true);
                              } else {
                                _executeRestore();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConfirming ? AppColors.coral : AppColors.aqua,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: AppColors.surface,
                        disabledForegroundColor: AppColors.textTertiary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        !_isConfirming ? 'Preview & Restore' : 'Confirm Overwrite',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog for resetting all habit data safely.
class BackupResetDialog extends StatelessWidget {
  const BackupResetDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const BackupResetDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: AppColors.rose, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Reset Habit Data',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'This will permanently delete all your habits, activity histories, and streaks on this device.\n\nYour app settings, notification preferences, and username will NOT be changed.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      final habitRepo = context.read<HabitRepository>();
                      await habitRepo.replaceHabits([]);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All habit data has been reset.'),
                            backgroundColor: AppColors.surfaceHigh,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Delete All Habits'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
