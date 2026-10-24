// Reads and writes the save game (one JSON file) and the player's backups.
//
// Why: everything is offline. Writes go to a temp file and are renamed over the
// real one, so a crash mid-write never leaves a half file. A backup is the same
// JSON wrapped in a small envelope, saved as `.mindisles`.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../domain/save_data.dart';
import '../constants/app_info.dart';

/// Summary of one backup file, shown in the backup list and the restore prompt.
class BackupInfo {
  const BackupInfo({
    required this.file,
    required this.createdAt,
    required this.automatic,
    required this.bytes,
    required this.levels,
    required this.stars,
  });
  final File? file;
  final DateTime createdAt;
  final bool automatic;
  final int bytes;
  final int levels;
  final int stars;
}

/// A decoded backup: its summary and the save inside it.
class BackupPayload {
  const BackupPayload(this.info, this.data);
  final BackupInfo info;
  final SaveData data;
}

class SaveStore {
  SaveStore(this.dir);

  /// App-private folder (application support) that holds save.json and backups/.
  final Directory dir;

  static const _file = 'save.json';
  static const _keepAuto = 5;

  File get _save => File(p.join(dir.path, _file));
  Directory get backupsDir => Directory(p.join(dir.path, 'backups'));

  Future<void> _queue = Future.value();

  /// Loads the save; null on first launch. A damaged file falls back to the
  /// newest backup instead of wiping progress.
  Future<SaveData?> load() async {
    if (await _save.exists()) {
      try {
        final json =
            jsonDecode(await _save.readAsString()) as Map<String, Object?>;
        return SaveData.fromJson(json);
      } catch (_) {
        final backups = await listBackups();
        for (final b in backups) {
          try {
            return decodeBackup(await b.file!.readAsBytes()).data;
          } catch (_) {}
        }
      }
    }
    return null;
  }

  /// Writes [data] atomically. Calls are serialised so the newest state always wins.
  Future<void> write(SaveData data) {
    _queue = _queue
        .then((_) async {
          await dir.create(recursive: true);
          final tmp = File('${_save.path}.tmp');
          await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
          await tmp.rename(_save.path);
        })
        .catchError((Object _) {});
    return _queue;
  }

  /// Wraps a save in the backup envelope.
  static Uint8List encodeBackup(
    SaveData data,
    DateTime now, {
    bool automatic = false,
  }) {
    final env = {
      'app': 'mind-isles',
      'version': AppInfo.saveVersion,
      'createdAt': now.millisecondsSinceEpoch,
      'automatic': automatic,
      'save': data.toJson(),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(env)));
  }

  /// Reads a backup file. Throws [FormatException] for anything that isn't one.
  static BackupPayload decodeBackup(Uint8List bytes, {File? file}) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('This file is not a Mind Isles backup.');
    }
    if (json is! Map || json['app'] != 'mind-isles' || json['save'] is! Map) {
      throw const FormatException('This file is not a Mind Isles backup.');
    }
    final version = json['version'];
    if (version is int && version > AppInfo.saveVersion) {
      throw const FormatException(
        'This backup is from a newer version of the app. Update the app first.',
      );
    }
    final data = SaveData.fromJson(
      (json['save'] as Map).cast<String, Object?>(),
    );
    final created = json['createdAt'] is int
        ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
        : DateTime.now();
    return BackupPayload(
      BackupInfo(
        file: file,
        createdAt: created,
        automatic: json['automatic'] == true,
        bytes: bytes.length,
        levels: data.games.values.fold(0, (n, g) => n + g.levels.length),
        stars: data.totalStars,
      ),
      data,
    );
  }

  /// Saves a backup into the app's own backups folder and keeps the newest few automatic ones.
  Future<BackupInfo> writeLocalBackup(
    SaveData data,
    DateTime now, {
    bool automatic = false,
  }) async {
    await backupsDir.create(recursive: true);
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    final f = File(
      p.join(
        backupsDir.path,
        '${automatic ? 'auto' : 'manual'}-$stamp.${AppInfo.backupExtension}',
      ),
    );
    final bytes = encodeBackup(data, now, automatic: automatic);
    await f.writeAsBytes(bytes, flush: true);
    if (automatic) await _pruneAuto();
    return decodeBackup(bytes, file: f).info;
  }

  /// Backups on this phone, newest first.
  Future<List<BackupInfo>> listBackups() async {
    if (!await backupsDir.exists()) return const [];
    final out = <BackupInfo>[];
    await for (final e in backupsDir.list()) {
      if (e is File && e.path.endsWith('.${AppInfo.backupExtension}')) {
        try {
          out.add(decodeBackup(await e.readAsBytes(), file: e).info);
        } catch (_) {}
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> _pruneAuto() async {
    final autos = (await listBackups()).where((b) => b.automatic).toList();
    for (final b in autos.skip(_keepAuto)) {
      try {
        await b.file?.delete();
      } catch (_) {}
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
