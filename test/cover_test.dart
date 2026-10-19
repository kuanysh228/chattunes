import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:telemusic/models.dart';
import 'package:telemusic/ui/components/cover.dart';
import 'package:telemusic/ui/components/cover_scope.dart';

import 'support/test_app.dart';

Track track(String id, {String title = 'Wildfire'}) =>
    Track(fileId: id, uniqueId: id, title: title, artist: 'A', duration: 10, addedAt: 0);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cover_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Widget app(Widget child, {File? Function(Track)? lookup}) => MaterialApp(
        home: Scaffold(
          body: lookup == null
              ? child
              : CoverScope(notifier: ValueNotifier(0), lookup: lookup, child: child),
        ),
      );

  File writeImage(String name) {
    final f = File('${dir.path}/$name.jpg');
    f.writeAsBytesSync(Uint8List.fromList(img.encodeJpg(img.Image(width: 20, height: 20), quality: 70)));
    return f;
  }

  testWidgets('without artwork it draws the placeholder letter', (tester) async {
    await tester.pumpWidget(app(Cover(track: track('a'))));
    expect(find.text('W'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('with artwork it shows the image above the placeholder', (tester) async {
    final file = writeImage('a');
    final px = (44 * tester.view.devicePixelRatio).round();
    await tester.runAsync(() => preloadImage(ResizeImage(FileImage(file), width: px, height: px)));
    await tester.pumpWidget(app(Cover(track: track('a')), lookup: (_) => file));

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('W'), findsOneWidget, reason: 'the placeholder is kept underneath');

    await tester.pump(const Duration(milliseconds: 300));
    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.image, isNotNull, reason: 'the artwork actually decodes and is drawn');
    expect(raw.width, 44);
  });

  testWidgets('an unreadable image file leaves the placeholder visible', (tester) async {
    final bad = File('${dir.path}/bad.jpg')..writeAsBytesSync([1, 2, 3, 4]);
    await tester.pumpWidget(app(Cover(track: track('a')), lookup: (_) => bad));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('W'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing image file does not crash the list', (tester) async {
    final gone = File('${dir.path}/nope.jpg');
    await tester.pumpWidget(app(Cover(track: track('a')), lookup: (_) => gone));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();

    expect(find.text('W'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only tracks that have artwork get an image', (tester) async {
    final file = writeImage('with');
    await tester.pumpWidget(app(
      Column(children: [
        Cover(track: track('with', title: 'Has')),
        Cover(track: track('without', title: 'Nope')),
      ]),
      lookup: (t) => t.uniqueId == 'with' ? file : null,
    ));

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('repainting when covers arrive: the scope notifies its dependents', (tester) async {
    final notifier = ValueNotifier(0);
    File? current;
    final file = writeImage('late');

    await tester.pumpWidget(MaterialApp(
      home: CoverScope(notifier: notifier, lookup: (_) => current, child: Cover(track: track('late'))),
    ));
    expect(find.byType(Image), findsNothing);

    current = file;
    notifier.value++;
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });
}
