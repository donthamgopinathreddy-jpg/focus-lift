import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/allowed_workout_apps.dart';
import '../../models/app_preferences.dart';
import '../../models/workout_session.dart';
import '../../services/focus_control/focus_control_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/workout_session_service.dart';
import '../focus/allowed_apps_screen.dart';
import '../settings/settings_screen.dart';
import '../workout/workout_screen.dart';

class HomeScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final WorkoutSessionService sessionService;
  final NotificationService notificationService;
  final FocusControlService focusService;
  final AppPreferences initialPreferences;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.sessionService,
    required this.notificationService,
    required this.focusService,
    required this.initialPreferences,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppPreferences _preferences;
  late int _selectedRestDuration;
  late AllowedWorkoutApps _allowedApps;
  WorkoutSession? _unresolvedSession;

  final List<int> _quickRestOptions = const [30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
    _selectedRestDuration = _preferences.defaultRestDurationSeconds;
    _allowedApps = _preferences.allowedApps;
    _checkForActiveSession();
  }

  void _checkForActiveSession() {
    final active = widget.sessionService.loadActiveSession();
    if (active != null) {
      _unresolvedSession = active;
    }
  }

  void _onRestDurationSelected(int seconds) {
    setState(() {
      _selectedRestDuration = seconds;
      _preferences = _preferences.copyWith(defaultRestDurationSeconds: seconds);
    });
    widget.storageService.saveRestDuration(seconds);
  }

  void _showCustomRestDialog() {
    int tempValue = _selectedRestDuration;
    final controller = TextEditingController(text: tempValue.toString());

    showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('CUSTOM REST DURATION'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter rest time in seconds (10 to 600s):',
                style: TextStyle(fontSize: 13, color: AppTheme.secondaryText),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accentBlue,
                ),
                decoration: const InputDecoration(
                  suffixText: 'sec',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed >= 10 && parsed <= 600) {
                  Navigator.pop(ctx, parsed);
                }
              },
              child: const Text('SET REST'),
            ),
          ],
        );
      },
    ).then((customSeconds) {
      if (customSeconds != null) {
        _onRestDurationSelected(customSeconds);
      }
    });
  }

  void _openManageAllowedApps() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AllowedAppsScreen(
          storageService: widget.storageService,
          focusService: widget.focusService,
          initialAllowed: _allowedApps,
          onAllowedChanged: (updated) {
            setState(() {
              _allowedApps = updated;
              _preferences = _preferences.copyWith(allowedApps: updated);
            });
          },
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SettingsScreen(
          storageService: widget.storageService,
          focusService: widget.focusService,
          initialPreferences: _preferences,
          onPreferencesChanged: (updated) {
            setState(() {
              _preferences = updated;
              _selectedRestDuration = updated.defaultRestDurationSeconds;
              _allowedApps = updated.allowedApps;
            });
          },
        ),
      ),
    );
  }

  void _startWorkout({WorkoutSession? existingSession}) {
    final session = existingSession ??
        WorkoutSession.start(
          selectedRestDuration: _selectedRestDuration,
        );

    widget.sessionService.saveActiveSession(session);

    setState(() {
      _unresolvedSession = null;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => WorkoutScreen(
          initialSession: session,
          sessionService: widget.sessionService,
          notificationService: widget.notificationService,
          focusService: widget.focusService,
          preferences: _preferences,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _checkForActiveSession();
        });
      }
    });
  }

  void _discardUnfinishedSession() {
    widget.focusService.stopFocusSession();
    widget.focusService.restoreNormalAccess();
    widget.sessionService.clearActiveSession();
    setState(() {
      _unresolvedSession = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCustomSelected = !_quickRestOptions.contains(_selectedRestDuration);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Brand Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'FOCUS LIFT',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppTheme.primaryText,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'TRAIN WITHOUT DISTRACTIONS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined, color: AppTheme.secondaryText),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Unfinished Session Recovery Banner
              if (_unresolvedSession != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentBlue.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center_rounded, color: AppTheme.accentBlue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UNFINISHED WORKOUT',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_unresolvedSession!.setsCompleted} sets completed',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _discardUnfinishedSession,
                        child: const Text('DISCARD', style: TextStyle(color: AppTheme.secondaryText, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                      ElevatedButton(
                        onPressed: () => _startWorkout(existingSession: _unresolvedSession),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('RESUME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Main Scrollable Setup
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: REST TIMER
                      _buildSectionTitle('REST TIMER'),
                      const SizedBox(height: 10),
                      Row(
                        children: _quickRestOptions.map((secs) {
                          final isSelected = _selectedRestDuration == secs;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildRestButton(
                                label: '${secs}s',
                                isSelected: isSelected,
                                onTap: () => _onRestDurationSelected(secs),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _showCustomRestDialog,
                          icon: Icon(
                            Icons.tune,
                            size: 14,
                            color: isCustomSelected ? AppTheme.accentBlue : AppTheme.secondaryText,
                          ),
                          label: Text(
                            isCustomSelected
                                ? 'CUSTOM: ${_selectedRestDuration}s'
                                : 'Custom Rest',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isCustomSelected ? AppTheme.accentBlue : AppTheme.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 2: ALLOWED DURING WORKOUT
                      _buildSectionTitle('ALLOWED DURING WORKOUT'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.music_note_rounded, color: AppTheme.accentBlue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Music Playback',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryText,
                                        ),
                                      ),
                                      Text(
                                        _allowedApps.selectedMusicAppName != null
                                            ? _allowedApps.selectedMusicAppName!
                                            : (_allowedApps.musicAllowed ? 'Audio enabled' : 'Disabled'),
                                        style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _allowedApps.musicAllowed ? AppTheme.primaryBlue.withAlpha(30) : AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _allowedApps.musicAllowed ? 'ENABLED' : 'OFF',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _allowedApps.musicAllowed ? AppTheme.accentBlue : AppTheme.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: AppTheme.border),
                            Row(
                              children: [
                                const Icon(Icons.phone_in_talk_rounded, color: AppTheme.accentBlue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Phone & Calls',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryText,
                                        ),
                                      ),
                                      Text(
                                        'Always available for essential use',
                                        style: TextStyle(fontSize: 11, color: AppTheme.secondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'ALWAYS ON',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _openManageAllowedApps,
                                icon: const Icon(Icons.tune, size: 14, color: AppTheme.secondaryText),
                                label: const Text(
                                  'Manage Allowed Apps',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // Section 3: Dominant Primary CTA — START FOCUS WORKOUT
              ElevatedButton(
                onPressed: () => _startWorkout(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppTheme.primaryBlue.withAlpha(100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.flash_on_rounded, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'START FOCUS WORKOUT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: AppTheme.secondaryText,
      ),
    );
  }

  Widget _buildRestButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppTheme.surfaceElevated : AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accentBlue : AppTheme.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppTheme.accentBlue : AppTheme.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}
