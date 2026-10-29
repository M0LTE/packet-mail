import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opened in main before the app starts, so the first frame knows the choice.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Override in main'));

/// Readable (true) or As sent (false), remembered across messages.
final readableProvider = NotifierProvider<ReadableChoice, bool>(ReadableChoice.new);

class ReadableChoice extends Notifier<bool> {
  static const _key = 'message.readable';

  @override
  bool build() => ref.watch(prefsProvider).getBool(_key) ?? true;

  void set(bool readable) {
    state = readable;
    ref.read(prefsProvider).setBool(_key, readable);
  }
}

/// Bulletins by date (true) or by category and area (false), remembered.
final bulletinsByDateProvider = NotifierProvider<BulletinsByDate, bool>(BulletinsByDate.new);

class BulletinsByDate extends Notifier<bool> {
  static const _key = 'bulletins.byDate';

  @override
  bool build() => ref.watch(prefsProvider).getBool(_key) ?? false;

  void set(bool byDate) {
    state = byDate;
    ref.read(prefsProvider).setBool(_key, byDate);
  }
}
