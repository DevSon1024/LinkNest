import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../models/link_model.dart';
import 'database_helper.dart';
import 'metadata_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: false,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  service.on('startFetching').listen((event) async {
    final dbHelper = DatabaseHelper();

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      final linksToFetch = await dbHelper.getPendingLinks();
      if (linksToFetch.isEmpty) {
        return;
      }

      for (final link in linksToFetch) {
        try {
          final metadata = await MetadataService.extractMetadata(link.url);
          if (metadata != null) {
            final updatedLink = link.copyWith(
              title: metadata.title,
              description: metadata.description,
              imageUrl: metadata.imageUrl,
              status: MetadataStatus.completed,
            );
            await dbHelper.updateLink(updatedLink);
          } else {
            await dbHelper.updateLink(link.copyWith(status: MetadataStatus.failed));
          }
        } catch (e) {
          await dbHelper.updateLink(link.copyWith(status: MetadataStatus.failed));
        }
      }
    });
  });
}

extension on DatabaseHelper {
  Future<List<LinkModel>> getPendingLinks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'links',
      where: 'status = ?',
      whereArgs: [MetadataStatus.pending.name],
      limit: 5, // Fetch in batches
    );
    return List.generate(maps.length, (i) => LinkModel.fromMap(maps[i]));
  }
}