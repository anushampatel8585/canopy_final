import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/habit_repository.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/backup_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  final NotificationService _notifications = NotificationService();

  late String _userName;
  late bool _remindersEnabled;
  late bool _missedHabitAlerts;
  late String _eveningCheckinTime;
  late bool _animationsEnabled;
  late bool _hapticsEnabled;

  @override
  void initState() {
    super.initState();
    _userName = _settings.userName;
    _remindersEnabled = _settings.remindersEnabled;
    _missedHabitAlerts = _settings.missedHabitAlertsEnabled;
    _eveningCheckinTime = _settings.eveningCheckinTime;
    _animationsEnabled = _settings.animationsEnabled;
    _hapticsEnabled = _settings.hapticsEnabled;
  }

  Future<void> _editUserName() async {
    final controller = TextEditingController(text: _userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Edit Name',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.aqua),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aqua,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && mounted) {
      await _settings.setUserName(newName);
      setState(() {
        _userName = _settings.userName;
      });
    }
  }

  TimeOfDay _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 20, minute: 30);
    }
  }

  String _formatTimeDisplay(BuildContext context, String timeString) {
    final tod = _parseTime(timeString);
    return tod.format(context);
  }

  Future<void> _pickEveningCheckinTime() async {
    final currentTod = _parseTime(_eveningCheckinTime);

    final picked = await showTimePicker(
      context: context,
      initialTime: currentTod,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.aqua,
              onPrimary: Colors.black,
              surface: AppColors.surfaceElevated,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.surfaceElevated,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final newTime = '$hourStr:$minuteStr';

      await _settings.setEveningCheckinTime(newTime);
      setState(() {
        _eveningCheckinTime = newTime;
      });

      // Reschedule missed-habit check-in notification with new time
      final habits = context.read<HabitRepository>().habits;
      await _notifications.scheduleMissedHabitCheckin(habits);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evening check-in updated to ${_formatTimeDisplay(context, newTime)}'),
            backgroundColor: AppColors.surfaceHigh,
          ),
        );
      }
    }
  }

  Future<void> _onToggleReminders(bool value) async {
    if (value) {
      final granted = await _notifications.requestNotificationPermission();
      await _notifications.requestExactAlarmPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device notification permissions are disabled. Please enable notifications in device settings to receive alerts.'),
            backgroundColor: AppColors.rose,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _remindersEnabled = value);
    await _settings.setRemindersEnabled(value);

    if (!value) {
      await _notifications.cancelAllPendingHabitReminderNotifications();
    } else if (mounted) {
      final habits = context.read<HabitRepository>().habits;
      await _notifications.syncAllHabitNotifications(habits);
    }
  }

  Future<void> _onToggleMissedHabits(bool value) async {
    if (value) {
      final granted = await _notifications.requestNotificationPermission();
      await _notifications.requestExactAlarmPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device notification permissions are disabled. Please enable notifications in device settings to receive alerts.'),
            backgroundColor: AppColors.rose,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    setState(() => _missedHabitAlerts = value);
    await _settings.setMissedHabitAlertsEnabled(value);

    if (mounted) {
      final habits = context.read<HabitRepository>().habits;
      await _notifications.scheduleMissedHabitCheckin(habits);
    }
  }

  Future<void> _sendTestNotification() async {
    final granted = await _notifications.requestNotificationPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device notification permissions are disabled. Please enable notifications in device settings to receive alerts.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    await _notifications.sendTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification tray.'),
          backgroundColor: AppColors.surfaceHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'Profile',
          children: [
            _SettingsActionTile(
              icon: Icons.person_outline_rounded,
              title: 'Name',
              subtitle: _userName,
              trailingIcon: Icons.edit_outlined,
              onTap: _editUserName,
            ),
            const _SettingsTile(
              icon: Icons.account_circle_outlined,
              title: 'Account',
              subtitle: 'Local only (Privacy-first)',
            ),
          ],
        ),
        _SettingsSection(
          title: 'Appearance & Feedback',
          children: [
            _SettingsSwitchTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Animations',
              subtitle: 'Subtle motion throughout CANOPY',
              value: _animationsEnabled,
              onChanged: (v) async {
                setState(() => _animationsEnabled = v);
                await _settings.setAnimationsEnabled(v);
              },
            ),
            _SettingsSwitchTile(
              icon: Icons.vibration_rounded,
              title: 'Haptic feedback',
              subtitle: 'Tactile response when logging habits',
              value: _hapticsEnabled,
              onChanged: (v) async {
                setState(() => _hapticsEnabled = v);
                await _settings.setHapticsEnabled(v);
              },
            ),
          ],
        ),
        _SettingsSection(
          title: 'Notifications',
          children: [
            _SettingsSwitchTile(
              icon: Icons.notifications_none_rounded,
              title: 'Habit reminders',
              subtitle: 'Daily alerts for scheduled habits',
              value: _remindersEnabled,
              onChanged: _onToggleReminders,
            ),
            _SettingsSwitchTile(
              icon: Icons.warning_amber_rounded,
              title: 'Missed habit alerts',
              subtitle: 'Evening reminder for incomplete habits',
              value: _missedHabitAlerts,
              onChanged: _onToggleMissedHabits,
            ),
            _SettingsActionTile(
              icon: Icons.access_time_rounded,
              title: 'Evening check-in time',
              subtitle: _formatTimeDisplay(context, _eveningCheckinTime),
              trailingIcon: Icons.arrow_forward_ios_rounded,
              onTap: _pickEveningCheckinTime,
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: AppColors.aqua),
              title: const Text('Send test notification'),
              subtitle: const Text(
                'Tap to verify sound and banner alerts',
                style: TextStyle(color: AppColors.textTertiary),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
              onTap: _sendTestNotification,
            ),
          ],
        ),
        _SettingsSection(
          title: 'Data & Backup',
          children: [
            _SettingsActionTile(
              icon: Icons.backup_outlined,
              title: 'Backup data',
              subtitle: 'Export habits and history as JSON',
              trailingIcon: Icons.arrow_forward_ios_rounded,
              onTap: () => BackupExportDialog.show(context),
            ),
            _SettingsActionTile(
              icon: Icons.restore_outlined,
              title: 'Restore data',
              subtitle: 'Import habits and history from JSON backup',
              trailingIcon: Icons.arrow_forward_ios_rounded,
              onTap: () => BackupRestoreDialog.show(context),
            ),
            _SettingsActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Reset all habit data',
              subtitle: 'Erase all habits and start fresh',
              titleColor: AppColors.rose,
              iconColor: AppColors.rose,
              trailingIcon: Icons.arrow_forward_ios_rounded,
              onTap: () => BackupResetDialog.show(context),
            ),
          ],
        ),
        _SettingsSection(
          title: 'General',
          children: [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About ${AppConfig.appName}',
              subtitle: AppConfig.appTagline,
            ),
            _SettingsTile(
              icon: Icons.numbers_rounded,
              title: 'App version',
              subtitle: AppConfig.appVersion,
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary)),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailingIcon;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingIcon,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(
        title,
        style: TextStyle(color: titleColor ?? AppColors.textPrimary),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary)),
      trailing: Icon(trailingIcon, size: 14, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary)),
      value: value,
      onChanged: onChanged,
    );
  }
}
