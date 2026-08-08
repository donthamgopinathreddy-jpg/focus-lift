import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/app_preferences.dart';
import '../../models/focus_mode.dart';
import '../../models/workout_session.dart';
import '../../services/local_storage_service.dart';
import '../../services/workout_session_service.dart';
import '../settings/settings_screen.dart';
import '../workout/workout_screen.dart';

class HomeScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final WorkoutSessionService sessionService;
  final AppPreferences initialPreferences;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.sessionService,
    required this.initialPreferences,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late AppPreferences _preferences;
  late int _selectedRestDuration;
  late FocusMode _selectedFocusMode;
  WorkoutSession? _unresolvedSession;

  final List<int> _quickRestOptions = const [30, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
    _selectedRestDuration = _preferences.defaultRestDurationSeconds;
    _selectedFocusMode = _preferences.focusMode;
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

  void _onFocusModeSelected(FocusMode mode) {
    setState(() {
      _selectedFocusMode = mode;
      _preferences = _preferences.copyWith(focusMode: mode);
    });
    widget.storageService.saveFocusMode(mode);
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
                minimumSize: const Size(100, 44),
                backgroundColor: AppTheme.primaryBlue,
              ),
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed >= 10 && parsed <= 600) {
                  Navigator.pop(ctx, parsed);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a duration between 10 and 600 seconds.'),
                      backgroundColor: AppTheme.warningOrange,
                    ),
                  );
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
          initialPreferences: _preferences,
          onPreferencesChanged: (updated) {
            setState(() {
              _preferences = updated;
              _selectedRestDuration = updated.defaultRestDurationSeconds;
              _selectedFocusMode = updated.focusMode;
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
        ),
      ),
    ).then((_) {
      // Recheck storage on return to home
      if (mounted) {
        setState(() {
          _checkForActiveSession();
        });
      }
    });
  }

  void _discardUnfinishedSession() {
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
              // Header & Branding with Settings Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: AppTheme.accentBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'FOCUS LIFT',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          Text(
                            'TRAIN WITHOUT DISTRACTIONS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _openSettings,
                    tooltip: 'Settings',
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppTheme.secondaryText,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Active Workout Recovery Banner (if app was reopened during an unfinished workout)
              if (_unresolvedSession != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_toggle_off, color: AppTheme.accentBlue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UNFINISHED WORKOUT',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppTheme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_unresolvedSession!.setsCompleted} sets • ${_unresolvedSession!.currentState.label}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _discardUnfinishedSession,
                        child: const Text('DISCARD', style: TextStyle(color: AppTheme.secondaryText, fontSize: 11)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          minimumSize: const Size(80, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _startWorkout(existingSession: _unresolvedSession),
                        child: const Text('RESUME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
                              child: _buildRestChoiceButton(
                                label: '${secs}s',
                                isSelected: isSelected,
                                onTap: () => _onRestDurationSelected(secs),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      // Custom rest option
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _showCustomRestDialog,
                          icon: Icon(
                            Icons.tune,
                            size: 16,
                            color: isCustomSelected ? AppTheme.accentBlue : AppTheme.secondaryText,
                          ),
                          label: Text(
                            isCustomSelected
                                ? 'CUSTOM: ${_selectedRestDuration}s'
                                : 'CUSTOM REST',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isCustomSelected ? AppTheme.accentBlue : AppTheme.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section 2: FOCUS MODE
                      _buildSectionTitle('FOCUS MODE'),
                      const SizedBox(height: 10),
                      Row(
                        children: FocusMode.values.map((mode) {
                          final isSelected = _selectedFocusMode == mode;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildFocusModeButton(
                                mode: mode,
                                isSelected: isSelected,
                                onTap: () => _onFocusModeSelected(mode),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      // Description Card for selected focus mode
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppTheme.accentBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _selectedFocusMode.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.secondaryText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Section 3: Large Dominant Primary CTA — START WORKOUT
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
                    Icon(Icons.play_arrow_rounded, size: 30),
                    SizedBox(width: 8),
                    Text(
                      'START WORKOUT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
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
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppTheme.secondaryText,
      ),
    );
  }

  Widget _buildRestChoiceButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppTheme.primaryBlue : AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accentBlue : AppTheme.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : AppTheme.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusModeButton({
    required FocusMode mode,
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
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.accentBlue : AppTheme.border,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Text(
            mode.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isSelected ? AppTheme.accentBlue : AppTheme.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}
