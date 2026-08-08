import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/allowed_workout_apps.dart';
import '../../services/focus_control/app_info.dart';
import '../../services/focus_control/focus_control_service.dart';
import '../../services/local_storage_service.dart';

/// Screen allowing the user to configure which applications are permitted during workouts.
class AllowedAppsScreen extends StatefulWidget {
  final LocalStorageService storageService;
  final FocusControlService focusService;
  final AllowedWorkoutApps initialAllowed;
  final ValueChanged<AllowedWorkoutApps>? onAllowedChanged;

  const AllowedAppsScreen({
    super.key,
    required this.storageService,
    required this.focusService,
    required this.initialAllowed,
    this.onAllowedChanged,
  });

  @override
  State<AllowedAppsScreen> createState() => _AllowedAppsScreenState();
}

class _AllowedAppsScreenState extends State<AllowedAppsScreen> {
  late AllowedWorkoutApps _allowed;
  List<AppInfo> _installedMusicApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _allowed = widget.initialAllowed;
    _loadMusicApps();
  }

  Future<void> _loadMusicApps() async {
    final apps = await widget.focusService.discoverInstalledMusicApps();
    if (!mounted) return;
    setState(() {
      _installedMusicApps = apps;
      _isLoading = false;
    });
  }

  void _updateAllowed(AllowedWorkoutApps updated) {
    setState(() {
      _allowed = updated;
    });
    widget.storageService.saveAllowedApps(updated);
    widget.onAllowedChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ALLOWED APPS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Explanation Header
                  const Text(
                    'ALLOWED DURING WORKOUT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose the apps you may need while training. Distracting phone use will be restricted as much as the OS allows.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.secondaryText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 1: ESSENTIAL
                  _buildSectionHeader('ESSENTIAL'),
                  const SizedBox(height: 10),
                  _buildAppTile(
                    icon: Icons.phone_in_talk_rounded,
                    title: 'Phone & Calls',
                    subtitle: 'Always available for essential and emergency use',
                    trailing: const Text(
                      'ALWAYS ON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: AppTheme.accentBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section 2: MUSIC
                  _buildSectionHeader('MUSIC & AUDIO'),
                  const SizedBox(height: 10),
                  _buildAppTile(
                    icon: Icons.music_note_rounded,
                    title: 'Music Playback',
                    subtitle: _allowed.selectedMusicAppName != null
                        ? 'Selected: ${_allowed.selectedMusicAppName}'
                        : 'Quick access to your audio player',
                    trailing: Switch(
                      value: _allowed.musicAllowed,
                      onChanged: (val) {
                        _updateAllowed(_allowed.copyWith(musicAllowed: val));
                      },
                    ),
                  ),

                  // Music chooser list if music is enabled
                  if (_allowed.musicAllowed && _installedMusicApps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PREFERRED MUSIC APP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._installedMusicApps.map((app) {
                            final isChosen = _allowed.selectedMusicPackage == app.packageName;
                            return RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppTheme.primaryBlue,
                              value: app.packageName,
                              groupValue: _allowed.selectedMusicPackage,
                              title: Text(
                                app.appName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                                  color: isChosen ? AppTheme.primaryText : AppTheme.secondaryText,
                                ),
                              ),
                              onChanged: (pkg) {
                                _updateAllowed(
                                  _allowed.copyWith(
                                    selectedMusicPackage: pkg,
                                    selectedMusicAppName: app.appName,
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Section 3: OPTIONAL
                  _buildSectionHeader('OPTIONAL TOOLS'),
                  const SizedBox(height: 10),
                  _buildAppTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Messages',
                    subtitle: 'Allow communication during training',
                    trailing: Switch(
                      value: _allowed.messagesAllowed,
                      onChanged: (val) {
                        _updateAllowed(_allowed.copyWith(messagesAllowed: val));
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAppTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Camera',
                    subtitle: 'Allow recording lifts or form checks',
                    trailing: Switch(
                      value: _allowed.cameraAllowed,
                      onChanged: (val) {
                        _updateAllowed(_allowed.copyWith(cameraAllowed: val));
                      },
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

  Widget _buildAppTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.surfaceElevated,
            child: Icon(icon, color: AppTheme.accentBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
  }
}
