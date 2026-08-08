import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/app_preferences.dart';
import '../../models/workout_session.dart';
import '../../services/focus_control/focus_control_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/workout_session_service.dart';
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
  WorkoutSession? _unresolvedSession;
  bool _isLaunching = false;

  final List<int> _quickRestOptions = const [30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
    _selectedRestDuration = _preferences.defaultRestDurationSeconds;
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
    final controller = TextEditingController(text: _selectedRestDuration.toString());

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
            });
          },
        ),
      ),
    );
  }

  void _startWorkout({WorkoutSession? existingSession}) {
    if (_isLaunching) return;
    setState(() {
      _isLaunching = true;
    });

    final session = existingSession ??
        WorkoutSession.start(
          selectedRestDuration: _selectedRestDuration,
        );

    widget.sessionService.saveActiveSession(session);

    setState(() {
      _unresolvedSession = null;
      _isLaunching = false;
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
              // TOP: Brand Header & Settings Icon
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
              const SizedBox(height: 16),

              // Unfinished Session Recovery Banner
              if (_unresolvedSession != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentBlue.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center_rounded, color: AppTheme.accentBlue, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UNFINISHED WORKOUT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryText,
                              ),
                            ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('RESUME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // REST TIMER Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'REST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showCustomRestDialog,
                    child: Text(
                      isCustomSelected ? 'CUSTOM: ${_selectedRestDuration}s' : 'Custom',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isCustomSelected ? AppTheme.accentBlue : AppTheme.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: _quickRestOptions.map((secs) {
                  final isSelected = _selectedRestDuration == secs;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _buildRestButton(
                        label: '${secs}s',
                        isSelected: isSelected,
                        onTap: () => _onRestDurationSelected(secs),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(flex: 1),

              // CENTER: Large Circular Blue LAUNCH Button (Dominant UI element)
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Material(
                    color: AppTheme.primaryBlue,
                    shape: const CircleBorder(),
                    elevation: 12,
                    shadowColor: AppTheme.primaryBlue.withAlpha(160),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: AppTheme.accentBlue.withAlpha(100),
                      onTap: () => _startWorkout(),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'LAUNCH',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // BELOW LAUNCH BUTTON: Available during workout section
              Column(
                children: [
                  const Text(
                    'AVAILABLE DURING WORKOUT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAvailableTool(
                        icon: Icons.music_note_rounded,
                        label: 'MUSIC',
                      ),
                      _buildAvailableTool(
                        icon: Icons.phone_in_talk_rounded,
                        label: 'CALLS',
                      ),
                      _buildAvailableTool(
                        icon: Icons.camera_alt_outlined,
                        label: 'CAMERA',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Emergency calling remains available.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableTool({required IconData icon, required String label}) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.accentBlue, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppTheme.primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildRestButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppTheme.surfaceElevated : AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accentBlue : AppTheme.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected ? AppTheme.accentBlue : AppTheme.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}
