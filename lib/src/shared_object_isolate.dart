import 'dart:async';
import 'dart:isolate';

import 'shared_object.dart';
import 'shared_reference.dart';

/// A [SharedObject] implementation through [Isolate]s.
abstract class SharedObjectIsolate<R extends SharedReferenceIsolate>
    implements SharedObjectReferenceable<R> {
  @override
  final String id;

  SharedObjectIsolate(this.id);

  late final RawReceivePort _receivePort = RawReceivePort(
      _onReceiveIsolateMessage, "SharedObjectIsolate[$id]._receivePort");

  SendPort get isolateSendPort => _receivePort.sendPort;

  void _onReceiveIsolateMessage(SharedObjectIsolateMessage m);
}

/// The main [SharedObjectIsolate] implementation.
abstract class SharedObjectIsolateMain<R extends SharedReferenceIsolate>
    extends SharedObjectIsolate<R> with SharedObjectMain {
  SharedObjectIsolateMain(super.id);

  @override
  void _onReceiveIsolateMessage(SharedObjectIsolateMessage m) {
    if (m is! SharedObjectIsolateRequestMessage) {
      throw StateError("Expected a `SharedObjectIsolateRequestMessage`: $m");
    }

    onReceiveIsolateRequestMessage(m);
  }

  void onReceiveIsolateRequestMessage(SharedObjectIsolateRequestMessage m);
}

/// The auxiliary [SharedObjectIsolate] implementation.
abstract class SharedObjectIsolateAuxiliary<REF extends SharedReferenceIsolate,
    R> extends SharedObjectIsolate<REF> with SharedObjectAuxiliary {
  SharedObjectIsolateAuxiliary(super.id);

  SendPort get serverPort;

  final Map<int, Completer<R?>> _waitingResponse = {};

  @override
  void _onReceiveIsolateMessage(SharedObjectIsolateMessage m) {
    if (m is! SharedObjectIsolateResponseMessage) {
      throw StateError("Expected a `SharedObjectIsolateResponseMessage`: $m");
    }

    var response = m.response as R?;

    var completer = _waitingResponse.remove(m.id);

    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  int _msgIDCounter = 0;

  Future<T?> sendRequest<T extends R>(List args) {
    var msgID = ++_msgIDCounter;
    var completer = _waitingResponse[msgID] = Completer<T?>();

    var msg = SharedObjectIsolateRequestMessage(msgID, isolateSendPort, args);

    serverPort.send(msg);

    return completer.future;
  }

  Future<T> sendRequestNotNull<T extends R>(List args) => sendRequest<T>(args)
      .then((r) => r ?? (throw StateError("Null response")));
}

class SharedObjectIsolateMessage {
  final int id;

  SharedObjectIsolateMessage(this.id);
}

class SharedObjectIsolateRequestMessage extends SharedObjectIsolateMessage {
  final List args;
  final SendPort responsePort;

  SharedObjectIsolateRequestMessage(super.id, this.responsePort, this.args);

  SharedObjectIsolateResponseMessage<R> createResponse<R>(R response) =>
      SharedObjectIsolateResponseMessage(id, response);

  void sendResponse<R>(R response) =>
      responsePort.send(createResponse(response));
}

class SharedObjectIsolateResponseMessage<R> extends SharedObjectIsolateMessage {
  final R response;

  SharedObjectIsolateResponseMessage(super.id, this.response);

  SharedObjectIsolateResponseMessage<T> cast<T>() =>
      this as SharedObjectIsolateResponseMessage<T>;
}

/// Base class for a [SharedReference] that works through [Isolate]s.
abstract class SharedReferenceIsolate extends SharedReference {
  /// The port for the "server" that responds to requests from the auxiliary
  /// instance [Isolate], processed by the main instance [Isolate].
  final SendPort serverPort;

  SharedReferenceIsolate(super.id, this.serverPort);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
      };

  @override
  String toString() => 'SharedReference${toJson()}';
}
