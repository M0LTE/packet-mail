import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opened in main before the app starts, so the first frame knows the choice.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('Override in main'));

/// Readable (true) or As sent (false): the one view choice the app remembers.
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
