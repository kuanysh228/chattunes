import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../models.dart';

/// Tells every [Cover] below it where a track's cover image is, and repaints
/// them when a download finishes. Without a scope, covers are just generated
/// placeholders, which is what tests and theme previews show.
class CoverScope extends InheritedNotifier<ChangeNotifier> {
  const CoverScope({
    super.key,
    required ChangeNotifier notifier,
    required this.lookup,
    required super.child,
  }) : super(notifier: notifier);

  /// Returns the image file for a track, or null when it has none.
  final File? Function(Track track) lookup;

  static File? imageFor(BuildContext context, Track track) =>
      context.dependOnInheritedWidgetOfExactType<CoverScope>()?.lookup(track);
}
