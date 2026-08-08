import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/app_preferences.dart';
import '../../models/workout_session.dart';
import '../../models/workout_state.dart';
import '../../services/alert_service.dart';
import '../../services/focus_control/focus_control_service.dart';
import '../../services/notification_service.dart';
import '../../services/wakelock_service.dart';
import '../../services/workout_session_service.dart';
import '../summary/workout_summary_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final WorkoutSession initialSession;
  final WorkoutSessionService sessionService;
  final NotificationService notificationService;
  final FocusControlService focusService;
  final AppPreferences preferences;

  const WorkoutScreen({
    super.key,
    required this.initialSession,
    required this.sessionService,
    required this.notificationService,
    required this.focusService,
    required this.preferences,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with WidgetsBindingObserver {
  late WorkoutSession _session;
  late AppPreferences _preferences;
  Timer? _ticker;
  DateTime _currentTime = DateTime.now();
  bool _alertTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = widget.initialSession;
    _preferences = widget.preferences;
    widget.sessionService.saveActiveSession(_session);

    // Request notification permission contextually
    widget.notificationService.requestPermission();

    // Enable wakelock if Keep Screen Awake is preferred
    WakelockService.setAwake(_preferences.keepScreenAwake);

    // Start Focus workout session with user's allowed apps configuration
    widget.focusService.startFocusWorkout(_preferences.allowedApps);

    // Schedule notification if starting in resting state
    if (_session.currentState == WorkoutState.resting && _session.restEndsAt != null) {
      widget.notificationService.scheduleRestNotification(
        restEndsAt: _session.restEndsAt!,
        nextSetNumber: _session.setsCompleted + 1,
      );
    }

    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _currentTime = now;
        if (_session.currentState == WorkoutState.resting && _session.isRestExpired(now)) {
          _session = _session.copyWith(currentState: WorkoutState.restComplete);
          widget.sessionService.saveActiveSession(_session);

          if (!_alertTriggered) {
            _alertTriggered = true;
            AlertService.triggerRestCompleteAlert(
              soundEnabled: _preferences.soundEnabled,
              vibrationEnabled: _preferences.vibrationEnabled,
            );
            widget.notificationService.cancelRestNotification();
          }
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-synchronize timestamps immediately on foreground resume
      final now = DateTime.now();
      setState(() {
        _currentTime = now;
        final evaluated = _session.evaluatedAt(now);
        if (_session.currentState == WorkoutState.resting &&
            evaluated.currentState == WorkoutState.restComplete &&
            !_alertTriggered) {
          _alertTriggered = true;
          AlertService.triggerRestCompleteAlert(
            soundEnabled: _preferences.soundEnabled,
            vibrationEnabled: _preferences.vibrationEnabled,
          );
        }
        _session = evaluated;
      });
      widget.sessionService.saveActiveSession(_session);
      widget.notificationService.cancelRestNotification();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    widget.notificationService.cancelRestNotification();
    WakelockService.release();
    widget.focusService.stopFocusSession();
    widget.focusService.restoreNormalAccess();
    super.dispose();
  }

  void _onEndSet() {
    final now = DateTime.now();
    _alertTriggered = false;

    setState(() {
      _currentTime = now;
      _session = _session.endSet(timestamp: now);
    });

    widget.sessionService.saveActiveSession(_session);

    if (_session.restEndsAt != null) {
      widget.notificationService.scheduleRestNotification(
        restEndsAt: _session.restEndsAt!,
        nextSetNumber: _session.setsCompleted + 1,
      );
    }
  }

  void _onSkipRest() {
    final now = DateTime.now();
    _alertTriggered = false;
    widget.notificationService.cancelRestNotification();

    setState(() {
      _currentTime = now;
      _session = _session.skipRest();
    });

    widget.sessionService.saveActiveSession(_session);
  }

  void _onStartNextSet() {
    final now = DateTime.now();
    _alertTriggered = false;
    widget.notificationService.cancelRestNotification();

    setState(() {
      _currentTime = now;
      _session = _session.startNextSet();
    });

    widget.sessionService.saveActiveSession(_session);
  }

  Future<void> _onQuickMusic() async {
    final launched = await widget.focusService.launchMusicApp(
      _preferences.allowedApps.selectedMusicPackage,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio player active in background or default music app opened.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onQuickCall() async {
    await widget.focusService.launchPhoneApp();
  }

  void _confirmFinishWorkout() {
    showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('FINISH WORKOUT?'),
          content: const Text(
            'Your current workout will end.',
            style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.secondaryText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                minimumSize: const Size(90, 42),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('FINISH'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _finalizeWorkout();
      }
    });
  }

  void _finalizeWorkout() {
    _ticker?.cancel();
    widget.notificationService.cancelRestNotification();
    WakelockService.release();
    widget.focusService.stopFocusSession();
    widget.focusService.restoreNormalAccess();

    final finishedSession = _session.finishWorkout();
    widget.sessionService.clearActiveSession();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => WorkoutSummaryScreen(session: finishedSession),
      ),
    );
  }

  String _formatElapsedTime(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatRestCountdown(Duration remaining) {
    final totalSeconds = remaining.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _session.elapsedDuration(_currentTime);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmFinishWorkout();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Navigation Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FOCUS LIFT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        Text(
                          _session.currentState == WorkoutState.active
                              ? 'WORKOUT'
                              : 'REST MODE',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppTheme.primaryText,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _confirmFinishWorkout,
                      icon: const Icon(Icons.stop_circle_outlined, size: 18, color: AppTheme.secondaryText),
                      label: const Text(
                        'FINISH',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main Workout Content by State
                Expanded(
                  child: _session.currentState == WorkoutState.active
                      ? _buildActiveWorkoutView(elapsed)
                      : _buildRestView(elapsed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveWorkoutView(Duration elapsed) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(flex: 1),

        // Workout Elapsed Timer
        const Text(
          'ELAPSED TIME',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatElapsedTime(elapsed),
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: AppTheme.primaryText,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Sets Count Badge
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SET ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppTheme.secondaryText,
                ),
              ),
              Text(
                '${_session.setsCompleted + 1}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 20, color: AppTheme.border),
              const SizedBox(width: 14),
              Text(
                '${_session.setsCompleted} COMPLETED',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),

        const Spacer(flex: 2),

        // Dominant Primary Action: END SET
        ElevatedButton(
          onPressed: _onEndSet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: AppTheme.primaryBlue.withAlpha(120),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle_outline, size: 28),
              SizedBox(width: 10),
              Text(
                'END SET',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Access Controls: MUSIC & CALL
        _buildQuickAccessRow(),

        const SizedBox(height: 12),

        // Visually Secondary Action: Finish Workout
        TextButton(
          onPressed: _confirmFinishWorkout,
          child: const Text(
            'Finish Workout',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryText,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRestView(Duration elapsed) {
    final isRestComplete = _session.currentState == WorkoutState.restComplete;
    final remaining = _session.restRemaining(_currentTime);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Subtle Workout Elapsed Tracker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.secondaryText),
              const SizedBox(width: 6),
              Text(
                'WORKOUT: ${_formatElapsedTime(elapsed)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 1),

        // Rest Status Title
        Text(
          isRestComplete ? 'REST COMPLETE' : 'REST',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            color: isRestComplete ? AppTheme.successGreen : AppTheme.accentBlue,
          ),
        ),
        const SizedBox(height: 12),

        // Large Rest Countdown
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isRestComplete ? '00:00' : _formatRestCountdown(remaining),
            style: TextStyle(
              fontSize: 84,
              fontWeight: FontWeight.w900,
              letterSpacing: -2.0,
              color: isRestComplete ? AppTheme.successGreen : AppTheme.primaryText,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Rest Set Indicator
        Text(
          'SET ${_session.setsCompleted} COMPLETE',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppTheme.secondaryText,
          ),
        ),

        const Spacer(flex: 2),

        // Action Button: START NEXT SET (when complete) or SKIP REST (when resting)
        if (isRestComplete)
          ElevatedButton(
            onPressed: _onStartNextSet,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.play_arrow_rounded, size: 30),
                SizedBox(width: 8),
                Text(
                  'START NEXT SET',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          )
        else
          OutlinedButton(
            onPressed: _onSkipRest,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              side: const BorderSide(color: AppTheme.border, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'SKIP REST',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppTheme.primaryText,
              ),
            ),
          ),
        const SizedBox(height: 14),

        // Quick Access Controls: MUSIC & CALL
        _buildQuickAccessRow(),

        const SizedBox(height: 12),

        // Visually Secondary Action: Finish Workout
        TextButton(
          onPressed: _confirmFinishWorkout,
          child: const Text(
            'Finish Workout',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryText,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildQuickAccessRow() {
    return Row(
      children: [
        if (_preferences.allowedApps.musicAllowed)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _onQuickMusic,
              icon: const Icon(Icons.music_note_rounded, size: 18, color: AppTheme.accentBlue),
              label: const Text(
                'MUSIC',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (_preferences.allowedApps.musicAllowed && _preferences.allowedApps.callsAllowed)
          const SizedBox(width: 10),
        if (_preferences.allowedApps.callsAllowed)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _onQuickCall,
              icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: AppTheme.accentBlue),
              label: const Text(
                'CALL',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
      ],
    );
  }
}
