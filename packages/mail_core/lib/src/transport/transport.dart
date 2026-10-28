import 'dart:async';

/// A byte stream to a BBS. TCP today; AX.25 over Bluetooth KISS later.
abstract interface class Transport {
  /// Bytes from the BBS, in arrival order. Done when the far end closes.
  Stream<List<int>> get incoming;

  /// Sends [bytes]. Mark a password [secret] so a recorder never stores it.
  Future<void> write(List<int> bytes, {bool secret = false});

  Future<void> close();
}
