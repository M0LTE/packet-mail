import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'compose.dart';

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

/// Compact lists (true): one line per message, so about twice as many fit.
final compactListsProvider = NotifierProvider<CompactLists, bool>(CompactLists.new);

class CompactLists extends Notifier<bool> {
  static const _key = 'lists.compact';

  @override
  bool build() => ref.watch(prefsProvider).getBool(_key) ?? false;

  void set(bool compact) {
    state = compact;
    ref.read(prefsProvider).setBool(_key, compact);
  }
}

/// The tablet sidebar: open (true), folded down to its icons (false), or not
/// chosen yet (null), when the window's width decides.
final sidebarChoiceProvider = NotifierProvider<SidebarChoice, bool?>(SidebarChoice.new);

class SidebarChoice extends Notifier<bool?> {
  static const _key = 'sidebar.open';

  @override
  bool? build() => ref.watch(prefsProvider).getBool(_key);

  void set(bool open) {
    state = open;
    ref.read(prefsProvider).setBool(_key, open);
  }
}

/// Replies written above the quoted mail (true) or below it (false).
final replyAboveProvider = NotifierProvider<ReplyAbove, bool>(ReplyAbove.new);

class ReplyAbove extends Notifier<bool> {
  static const _key = 'reply.above';

  @override
  bool build() => ref.watch(prefsProvider).getBool(_key) ?? false;

  void set(bool above) {
    state = above;
    ref.read(prefsProvider).setBool(_key, above);
  }
}

/// How much of the original the last reply quoted, used for the next one.
final quoteAmountProvider = NotifierProvider<QuoteAmountChoice, QuoteAmount>(QuoteAmountChoice.new);

class QuoteAmountChoice extends Notifier<QuoteAmount> {
  static const _key = 'reply.quote';

  @override
  QuoteAmount build() {
    final saved = ref.watch(prefsProvider).getString(_key);
    return QuoteAmount.values.where((a) => a.name == saved).firstOrNull ?? QuoteAmount.start;
  }

  void set(QuoteAmount amount) {
    state = amount;
    ref.read(prefsProvider).setString(_key, amount.name);
  }
}
