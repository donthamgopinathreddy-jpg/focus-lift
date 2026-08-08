/// Holds the user's configuration of allowed applications during a workout.
class AllowedWorkoutApps {
  final bool callsAllowed;
  final bool musicAllowed;
  final bool messagesAllowed;
  final bool cameraAllowed;
  final String? selectedMusicPackage;
  final String? selectedMusicAppName;
  final Set<String> customAllowedPackages;

  const AllowedWorkoutApps({
    this.callsAllowed = true, // Phone & emergency always available
    this.musicAllowed = true, // Music enabled by default
    this.messagesAllowed = false,
    this.cameraAllowed = false,
    this.selectedMusicPackage,
    this.selectedMusicAppName,
    this.customAllowedPackages = const <String>{},
  });

  AllowedWorkoutApps copyWith({
    bool? callsAllowed,
    bool? musicAllowed,
    bool? messagesAllowed,
    bool? cameraAllowed,
    String? selectedMusicPackage,
    String? selectedMusicAppName,
    Set<String>? customAllowedPackages,
  }) {
    return AllowedWorkoutApps(
      callsAllowed: callsAllowed ?? this.callsAllowed,
      musicAllowed: musicAllowed ?? this.musicAllowed,
      messagesAllowed: messagesAllowed ?? this.messagesAllowed,
      cameraAllowed: cameraAllowed ?? this.cameraAllowed,
      selectedMusicPackage: selectedMusicPackage ?? this.selectedMusicPackage,
      selectedMusicAppName: selectedMusicAppName ?? this.selectedMusicAppName,
      customAllowedPackages: customAllowedPackages ?? this.customAllowedPackages,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callsAllowed': callsAllowed,
      'musicAllowed': musicAllowed,
      'messagesAllowed': messagesAllowed,
      'cameraAllowed': cameraAllowed,
      'selectedMusicPackage': selectedMusicPackage,
      'selectedMusicAppName': selectedMusicAppName,
      'customAllowedPackages': customAllowedPackages.toList(),
    };
  }

  factory AllowedWorkoutApps.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AllowedWorkoutApps();

    return AllowedWorkoutApps(
      callsAllowed: map['callsAllowed'] as bool? ?? true,
      musicAllowed: map['musicAllowed'] as bool? ?? true,
      messagesAllowed: map['messagesAllowed'] as bool? ?? false,
      cameraAllowed: map['cameraAllowed'] as bool? ?? false,
      selectedMusicPackage: map['selectedMusicPackage'] as String?,
      selectedMusicAppName: map['selectedMusicAppName'] as String?,
      customAllowedPackages: (map['customAllowedPackages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
    );
  }
}
