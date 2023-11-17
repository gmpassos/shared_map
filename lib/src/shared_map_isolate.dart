import 'dart:async';
import 'dart:isolate';

import 'shared_map_base.dart';

abstract class SharedIsolate extends SharedType {
  @override
  final String id;

  SharedIsolate(this.id);

  late final RawReceivePort _receivePort =
      RawReceivePort(_onReceiveMessage, "SharedStore[$id]._receivePort");

  void _onReceiveMessage(m);
}

abstract class SharedStoreIsolate extends SharedIsolate implements SharedStore {
  static final Map<String, WeakReference<SharedStoreIsolate>> _instances = {};

  SharedStoreIsolate(super.id) {
    _setupInstance();
  }

  void _setupInstance() {
    var prev = _instances[id];
    if (identical(prev, this)) {
      return;
    }
    _instances[id] = WeakReference(this);
  }

  final Map<String, SharedMapIsolate> _sharedMaps = {};
}

class SharedStoreIsolateServer extends SharedStoreIsolate {
  SharedStoreIsolateServer(String id) : super(id);

  @override
  void _onReceiveMessage(m) {
    if (m is List) {
      var clientPort = m[0] as SendPort;
      var messageID = m[1] as int;
      var id = m[2] as String;

      var sharedMap = _sharedMaps[id];

      clientPort.send([messageID, sharedMap?.sharedReference()]);
      return;
    }

    throw StateError("Unknown message type: $m");
  }

  @override
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(String id) {
    var sharedMap = _sharedMaps[id];
    if (sharedMap != null) {
      return sharedMap as SharedMap<K, V>;
    }

    return createSharedMap(sharedStore: this, id: id);
  }

  @override
  SharedStoreReferenceIsolate sharedReference() =>
      SharedStoreReferenceIsolate(id, _receivePort.sendPort);
}

class SharedStoreIsolateClient extends SharedStoreIsolate {
  final SendPort _serverPort;

  SharedStoreIsolateClient(super.id, this._serverPort);

  @override
  void _onReceiveMessage(m) {
    if (m is List) {
      var messageID = m[0] as int;
      var sharedReference = m[1];

      var completer = _waitingResponse.remove(messageID);

      if (completer != null && !completer.isCompleted) {
        completer.complete(sharedReference);
      }

      return;
    }

    throw StateError("Unknown message type: $m");
  }

  int _msgIDCounter = 0;

  final Map<int, Completer<SharedMapReferenceIsolate?>> _waitingResponse = {};

  @override
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(String id) {
    var sharedMap = _sharedMaps[id];
    if (sharedMap != null) {
      return sharedMap as SharedMap<K, V>;
    }

    var msgID = ++_msgIDCounter;
    var completer = _waitingResponse[msgID] = Completer();

    _serverPort.send([_receivePort.sendPort, msgID, id]);

    return completer.future.then((ref) {
      return createSharedMap(sharedReference: ref!);
    });
  }

  @override
  SharedStoreReferenceIsolate sharedReference() =>
      SharedStoreReferenceIsolate(id, _serverPort);
}

abstract class SharedMapIsolate<K, V> extends SharedIsolate
    implements SharedMap<K, V> {
  @override
  final SharedStore sharedStore;

  SharedMapIsolate(this.sharedStore, super.id);
}

class SharedMapIsolateServer<K, V> extends SharedMapIsolate<K, V>
    implements SharedMap<K, V> {
  final Map<K, V?> _entries;

  SharedMapIsolateServer(super.sharedStore, super.id) : _entries = {};

  @override
  void _onReceiveMessage(m) {
    if (m is List) {
      var clientPort = m[0] as SendPort;
      var messageID = m[1] as int;
      var key = m[2];

      final mLength = m.length;
      V? value;

      if (mLength == 4) {
        value = _entries[key] = m[3];
      } else if (mLength == 5) {
        var prev = _entries[key];
        if (prev == null) {
          value = _entries[key] = m[3];
        } else {
          value = prev;
        }
      } else {
        value = _entries[key];
      }

      clientPort.send([messageID, value]);
      return;
    }

    throw StateError("Unknown message type: $m");
  }

  @override
  FutureOr<V?> get(K key) {
    return _entries[key];
  }

  @override
  FutureOr<V?> put(K key, V? value) {
    return _entries[key] = value;
  }

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) {
    var prev = _entries[key];
    if (prev == null) {
      return _entries[key] = absentValue;
    } else {
      return prev;
    }
  }

  @override
  SharedMapReferenceIsolate sharedReference() => SharedMapReferenceIsolate(
      id, sharedStore.sharedReference(), _receivePort.sendPort);
}

class SharedMapIsolateClient<K, V> extends SharedMapIsolate<K, V>
    implements SharedMap<K, V> {
  final SendPort _serverPort;

  SharedMapIsolateClient(super.sharedStore, super.id, this._serverPort);

  int _msgIDCounter = 0;

  final Map<int, Completer<V?>> _waitingResponse = {};

  @override
  void _onReceiveMessage(m) {
    if (m is List) {
      var messageID = m[0] as int;
      var value = m[1];

      var completer = _waitingResponse.remove(messageID);

      if (completer != null && !completer.isCompleted) {
        completer.complete(value);
      }

      return;
    }

    throw StateError("Unknown message type: $m");
  }

  @override
  Future<V?> get(K key) async {
    var msgID = ++_msgIDCounter;
    var completer = _waitingResponse[msgID] = Completer();

    _serverPort.send([_receivePort.sendPort, msgID, key]);

    return completer.future;
  }

  @override
  FutureOr<V?> put(K key, V? value) {
    var msgID = ++_msgIDCounter;
    var completer = _waitingResponse[msgID] = Completer();

    _serverPort.send([_receivePort.sendPort, msgID, key, value]);

    return completer.future;
  }

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) {
    var msgID = ++_msgIDCounter;
    var completer = _waitingResponse[msgID] = Completer();

    _serverPort.send([_receivePort.sendPort, msgID, key, absentValue, true]);

    return completer.future;
  }

  @override
  SharedMapReference sharedReference() =>
      SharedMapReferenceIsolate(id, sharedStore.sharedReference(), _serverPort);
}

class SharedStoreReferenceIsolate extends SharedStoreReference {
  final SendPort _serverPort;

  SharedStoreReferenceIsolate(super.id, this._serverPort);
}

class SharedMapReferenceIsolate extends SharedMapReference {
  final SendPort _serverPort;

  SharedMapReferenceIsolate(
      super.id, super.sharedStoreReference, this._serverPort);
}

SharedStore createSharedStore(
    {String? id, SharedStoreReference? sharedReference}) {
  if (sharedReference != null) {
    if (sharedReference is SharedStoreReferenceIsolate) {
      id ??= sharedReference.id;

      return SharedStoreIsolateClient(id, sharedReference._serverPort);
    }

    throw StateError(
        "Unexpected `SharedStoreReference` type: $sharedReference");
  } else {
    return SharedStoreIsolateServer(id!);
  }
}

SharedMap<K, V> createSharedMap<K, V>(
    {SharedStore? sharedStore,
    String? id,
    SharedMapReference? sharedReference}) {
  if (sharedReference != null) {
    if (sharedReference is SharedMapReferenceIsolate) {
      id ??= sharedReference.id;

      var sharedStoreReference =
          sharedReference.sharedStoreReference as SharedStoreReferenceIsolate;

      var sharedStoreID = sharedStoreReference.id;

      var sharedStore = SharedStoreIsolate._instances[sharedStoreID]?.target ??
          SharedStoreIsolateClient(
              sharedStoreID, sharedStoreReference._serverPort);

      var sharedMap = sharedStore._sharedMaps[id] ??=
          SharedMapIsolateClient<K, V>(
              sharedStore, id, sharedReference._serverPort);
      return sharedMap as SharedMap<K, V>;
    }
  } else if (sharedStore is SharedStoreIsolate) {
    var sharedMap = sharedStore._sharedMaps[id!] ??=
        SharedMapIsolateServer<K, V>(sharedStore, id);
    return sharedMap as SharedMap<K, V>;
  }

  throw StateError("Unexpected `SharedMapReference` type: $sharedReference");
}
