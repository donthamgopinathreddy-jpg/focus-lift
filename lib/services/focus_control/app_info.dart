/// Represents an application discovered on the user's device.
class AppInfo {
  final String appName;
  final String packageName;
  final bool isSelected;

  const AppInfo({
    required this.appName,
    required this.packageName,
    this.isSelected = false,
  });

  AppInfo copyWith({
    String? appName,
    String? packageName,
    bool? isSelected,
  }) {
    return AppInfo(
      appName: appName ?? this.appName,
      packageName: packageName ?? this.packageName,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'packageName': packageName,
      'isSelected': isSelected,
    };
  }

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppInfo(
      appName: map['appName'] as String? ?? 'Unknown App',
      packageName: map['packageName'] as String? ?? '',
      isSelected: map['isSelected'] as bool? ?? false,
    );
  }
}
