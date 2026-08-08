import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/app_preferences.dart';
import '../../models/focus_mode.dart';
import '../../services/local_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final AppPreferences initialPreferences;
  final ValueChanged<AppPreferences> onPreferencesChanged;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.initialPreferences,
    required this.onPreferencesChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
  }

  void _updatePreferences(AppPreferences newPrefs) {
    setState(() {
      _preferences = newPrefs;
    });
    widget.onPreferencesChanged(newPrefs);
    widget.storageService.savePreferences(newPrefs);
  }

  void _showRestDurationPicker() {
    final options = [30, 45, 60, 90, 120, 150, 180];
    showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'DEFAULT REST DURATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map((secs) {
                  final isSelected = _preferences.defaultRestDurationSeconds == secs;
                  return ListTile(
                    title: Text(
                      '$secs SECONDS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppTheme.accentBlue : AppTheme.primaryText,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryBlue)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx, secs);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    ).then((selected) {
      if (selected != null) {
        _updatePreferences(
          _preferences.copyWith(defaultRestDurationSeconds: selected),
        );
      }
    });
  }

  void _showFocusModePicker() {
    showModalBottomSheet<FocusMode>(
      context: context,
      backgroundColor: AppTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'WORKOUT FOCUS MODE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...FocusMode.values.map((mode) {
                  final isSelected = _preferences.focusMode == mode;
                  return ListTile(
                    title: Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppTheme.accentBlue : AppTheme.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      mode.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryBlue)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx, mode);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    ).then((selected) {
      if (selected != null) {
        _updatePreferences(_preferences.copyWith(focusMode: selected));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Workout defaults section
          _buildSectionHeader('WORKOUT DEFAULTS'),
          _buildSettingCard(
            children: [
              _buildNavRow(
                title: 'Default Rest Timer',
                value: '${_preferences.defaultRestDurationSeconds}s',
                icon: Icons.timer_outlined,
                onTap: _showRestDurationPicker,
              ),
              const Divider(),
              _buildNavRow(
                title: 'Focus Mode',
                value: _preferences.focusMode.label,
                icon: Icons.shield_outlined,
                onTap: _showFocusModePicker,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Alerts & Haptics section
          _buildSectionHeader('ALERTS & FEEDBACK'),
          _buildSettingCard(
            children: [
              _buildSwitchRow(
                title: 'Sound Alert',
                subtitle: 'Play short chime when rest completes',
                icon: Icons.volume_up_outlined,
                value: _preferences.soundEnabled,
                onChanged: (val) {
                  _updatePreferences(_preferences.copyWith(soundEnabled: val));
                },
              ),
              const Divider(),
              _buildSwitchRow(
                title: 'Vibration',
                subtitle: 'Haptic alert at rest completion',
                icon: Icons.vibration_outlined,
                value: _preferences.vibrationEnabled,
                onChanged: (val) {
                  _updatePreferences(_preferences.copyWith(vibrationEnabled: val));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Display section
          _buildSectionHeader('DISPLAY'),
          _buildSettingCard(
            children: [
              _buildSwitchRow(
                title: 'Keep Screen Awake',
                subtitle: 'Active during workouts only, automatically released when finished',
                icon: Icons.wb_sunny_outlined,
                value: _preferences.keepScreenAwake,
                onChanged: (val) {
                  _updatePreferences(_preferences.copyWith(keepScreenAwake: val));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Privacy section
          _buildSectionHeader('PRIVACY'),
          _buildSettingCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 18, color: AppTheme.accentBlue),
                        SizedBox(width: 8),
                        Text(
                          '100% On-Device & Private',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryText,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Focus Lift has no login, no remote database, no analytics, and no tracking. Your workout sessions and preferences never leave your phone.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // About section
          _buildSectionHeader('ABOUT'),
          _buildSettingCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'FOCUS LIFT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: AppTheme.primaryText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Train Without Distractions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentBlue,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'by Cotrainr  •  Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Focus Lift is a lightweight workout-focus utility designed to help you stay away from distracting apps while training.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: AppTheme.secondaryText,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildNavRow({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.secondaryText),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryText,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentBlue,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppTheme.secondaryText),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
