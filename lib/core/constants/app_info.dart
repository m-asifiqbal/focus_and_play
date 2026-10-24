// The product name and other app-wide constants live here, in one place, so a
// rename (the name is still a working title) touches a single file.

/// App-wide identity constants.
abstract final class AppInfo {
  /// Working title shown in the UI.
  static const name = 'Mind Isles';

  /// File extension used for backups the player saves or restores.
  static const backupExtension = 'mindisles';

  /// Schema version of the save file; bump when the JSON shape changes.
  static const saveVersion = 1;
}
