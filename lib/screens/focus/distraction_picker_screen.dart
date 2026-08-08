import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/focus_control/app_info.dart';
import '../../services/focus_control/focus_authorization_status.dart';
import '../../services/focus_control/focus_control_service.dart';

/// Screen allowing the user to select which applications to flag as distractions during workouts.
class DistractionPickerScreen extends StatefulWidget {
  final FocusControlService focusService;

  const DistractionPickerScreen({
    super.key,
    required this.focusService,
  });

  @override
  State<DistractionPickerScreen> createState() => _DistractionPickerScreenState();
}

class _DistractionPickerScreenState extends State<DistractionPickerScreen> {
  List<AppInfo> _apps = [];
  Set<String> _selectedPackages = {};
  bool _isLoading = true;
  FocusAuthorizationStatus _authStatus = FocusAuthorizationStatus.notDetermined;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final status = await widget.focusService.getAuthorizationStatus();
    final savedDistractions = await widget.focusService.getSelectedDistractions();
    final launcherApps = await widget.focusService.getLauncherApps();

    if (!mounted) return;

    setState(() {
      _authStatus = status;
      _selectedPackages = savedDistractions.toSet();
      _apps = launcherApps;
      _isLoading = false;
    });
  }

  Future<void> _toggleAppSelection(String packageName) async {
    final updated = Set<String>.from(_selectedPackages);
    if (updated.contains(packageName)) {
      updated.remove(packageName);
    } else {
      updated.add(packageName);
    }

    setState(() {
      _selectedPackages = updated;
    });

    await widget.focusService.saveSelectedDistractions(updated.toList());
  }

  Future<void> _requestUsageAccess() async {
    await widget.focusService.requestAuthorization();
    // Re-check on return
    final status = await widget.focusService.getAuthorizationStatus();
    if (mounted) {
      setState(() {
        _authStatus = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _apps.where((app) {
      if (_searchQuery.isEmpty) return true;
      return app.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DISTRACTIONS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          if (_selectedPackages.isNotEmpty)
            TextButton(
              onPressed: () async {
                setState(() {
                  _selectedPackages.clear();
                });
                await widget.focusService.saveSelectedDistractions([]);
              },
              child: const Text(
                'CLEAR ALL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryText,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Usage Access Permission Banner if not authorized
                    if (_authStatus != FocusAuthorizationStatus.authorized)
                      _buildPermissionBanner(),

                    const SizedBox(height: 12),

                    // Search input
                    TextField(
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                      style: const TextStyle(color: AppTheme.primaryText, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search installed apps...',
                        hintStyle: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.secondaryText),
                        filled: true,
                        fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SELECT APPS TO RESTRICT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                        Text(
                          '${_selectedPackages.length} SELECTED',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Apps List
                    Expanded(
                      child: filteredApps.isEmpty
                          ? Center(
                              child: Text(
                                _apps.isEmpty
                                    ? 'No launchable apps discovered.'
                                    : 'No apps match "$_searchQuery"',
                                style: const TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredApps.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                              itemBuilder: (ctx, idx) {
                                final app = filteredApps[idx];
                                final isSelected = _selectedPackages.contains(app.packageName);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primaryBlue : AppTheme.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? AppTheme.primaryBlue.withAlpha(40)
                                          : AppTheme.surfaceElevated,
                                      child: Icon(
                                        isSelected
                                            ? Icons.block_rounded
                                            : Icons.apps_outlined,
                                        size: 20,
                                        color: isSelected
                                            ? AppTheme.accentBlue
                                            : AppTheme.secondaryText,
                                      ),
                                    ),
                                    title: Text(
                                      app.appName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryText,
                                      ),
                                    ),
                                    subtitle: Text(
                                      app.packageName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.secondaryText,
                                      ),
                                    ),
                                    trailing: Switch(
                                      value: isSelected,
                                      onChanged: (_) => _toggleAppSelection(app.packageName),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentBlue.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, size: 18, color: AppTheme.accentBlue),
              SizedBox(width: 8),
              Text(
                'USAGE ACCESS REQUIRED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppTheme.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Focus Lift uses app usage access only during active workouts to detect when you open distracting apps. Your data stays 100% on this device.',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText, height: 1.4),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _requestUsageAccess,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'ENABLE USAGE ACCESS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
