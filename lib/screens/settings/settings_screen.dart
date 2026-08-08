import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/app_preferences.dart';
import '../../services/focus_control/focus_control_service.dart';
import '../../services/local_storage_service.dart';
import '../focus/allowed_apps_screen.dart';

class SettingsScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final FocusControlService focusService;
  final AppPreferences initialPreferences;
  final ValueChanged<AppPreferences> onPreferencesChanged;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.focusService,
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

  void _openAllowedApps() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AllowedAppsScreen(
          storageService: widget.storageService,
          focusService: widget.focusService,
          initialAllowed: _preferences.allowedApps,
          onAllowedChanged: (updated) {
            _updatePreferences(_preferences.copyWith(allowedApps: updated));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Section: Workout & Rest
            _buildSectionHeader('WORKOUT TIMING'),
            const SizedBox(height: 8),
            _buildTileContainer(
              child: ListTile(
                title: const Text('Default Rest Timer', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryText)),
                subtitle: const Text('Preselected rest interval for workouts', style: TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
                trailing: Text(
                  '${_preferences.defaultRestDurationSeconds}s',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.accentBlue),
                ),
                onTap: _showRestDurationPicker,
              ),
            ),
            const SizedBox(height: 24),

            // Section: Device Experience
            _buildSectionHeader('DEVICE EXPERIENCE'),
            const SizedBox(height: 8),
            _buildTileContainer(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Sound Alert', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryText)),
                    subtitle: const Text('Brief chime when rest countdown reaches zero', style: TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
                    value: _preferences.soundEnabled,
                    onChanged: (val) {
                      _updatePreferences(_preferences.copyWith(soundEnabled: val));
                    },
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  SwitchListTile(
                    title: const Text('Vibration', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryText)),
                    subtitle: const Text('Haptic feedback on rest completion', style: TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
                    value: _preferences.vibrationEnabled,
                    onChanged: (val) {
                      _updatePreferences(_preferences.copyWith(vibrationEnabled: val));
                    },
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  SwitchListTile(
                    title: const Text('Keep Screen Awake', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryText)),
                    subtitle: const Text('Prevent display sleep exclusively during active workouts', style: TextStyle(color: AppTheme.secondaryText, fontSize: 12)),
                    value: _preferences.keepScreenAwake,
                    onChanged: (val) {
                      _updatePreferences(_preferences.copyWith(keepScreenAwake: val));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Allowed Apps
            _buildSectionHeader('WORKOUT PERMISSIONS'),
            const SizedBox(height: 8),
            _buildTileContainer(
              child: ListTile(
                title: const Text('Allowed Apps', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryText)),
                subtitle: Text(
                  'Music: ${_preferences.allowedApps.musicAllowed ? 'Enabled' : 'Off'} • Calls: Always on',
                  style: const TextStyle(color: AppTheme.secondaryText, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.secondaryText),
                onTap: _openAllowedApps,
              ),
            ),
            const SizedBox(height: 24),

            // Section: Privacy
            _buildSectionHeader('PRIVACY & STORAGE'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'Focus Lift stores workout settings and preferences on this device. No account is required.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section: About
            _buildSectionHeader('ABOUT'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'FOCUS LIFT',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: AppTheme.primaryText),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Train Without Distractions',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentBlue),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Brand: Cotrainr • Version 1.0.0 (Free & Offline)',
                    style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: AppTheme.secondaryText,
      ),
    );
  }

  Widget _buildTileContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}
