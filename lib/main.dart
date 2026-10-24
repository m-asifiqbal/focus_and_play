// Entry point: open the save, then run the app with it in place.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/storage/save_store.dart';
import 'domain/save_data.dart';
import 'state/save_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = SaveStore(await getApplicationSupportDirectory());
  final save = await store.load() ?? const SaveData();
  runApp(ProviderScope(
    overrides: [
      saveStoreProvider.overrideWithValue(store),
      initialSaveProvider.overrideWithValue(save),
    ],
    child: const MindIslesApp(),
  ));
}
