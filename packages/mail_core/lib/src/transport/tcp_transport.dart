import 'dart:async';
import 'dart:io';

import 'transport.dart';

/// A [Transport] over a TCP socket.
class TcpTransport implements Transport {
  TcpTransport._(this._socket);

  final Socket _socket;

  static Future<TcpTransport> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    return TcpTransport._(socket);
  }

  @override
  Stream<List<int>> get incoming => _socket;

  @override
  Future<void> write(List<int> bytes) async {
    _socket.add(bytes);
    await _socket.flush();
  }

  /// Closes at once. Waiting for the BBS to close its side can take half a
  /// minute (an FBB port waiting for a login), and every write is already flushed.
  @override
  Future<void> close() async => _socket.destroy();
}
