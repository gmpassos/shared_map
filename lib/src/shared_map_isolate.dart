import 'dart:async';
import 'dart:isolate';

import 'shared_map_base.dart';
import 'shared_map_cached.dart';
import 'shared_map_generic.dart' as generic;

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

  @override
  String toString() =>
      'SharedStoreIsolateServer[$id]{sharedMaps: ${_sharedMaps.length}}';
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

  @override
  String toString() =>
      'SharedStoreIsolateClient[$id]{sharedMaps: ${_sharedMaps.length}}';
}

abstract class SharedMapIsolate<K, V> extends SharedIsolate
    implements SharedMap<K, V> {
  @override
  final SharedStore sharedStore;

  SharedMapIsolate(this.sharedStore, super.id);

  @override
  OnSharedMapPut<K, V>? onPut;

  @override
  OnSharedMapRemove<K, V>? onRemove;
}

class SharedMapIsolateServer<K, V> extends SharedMapIsolate<K, V>
    implements SharedMapSync<K, V> {
  final Map<K, V> _entries;

  SharedMapIsolateServer(super.sharedStore, super.id) : _entries = {};

  @override
  void _onReceiveMessage(m) {
    if (m is List) {
      var op = m[0] as SharedMapOperation;
      var clientPort = m[1] as SendPort;
      var messageID = m[2] as int;

      Object? response;

      switch (op) {
        case SharedMapOperation.get:
          {
            var key = m[3];
            response = get(key);
          }
        case SharedMapOperation.put:
          {
            var key = m[3];
            var putValue = m[4];
            response = put(key, putValue);
          }
        case SharedMapOperation.putIfAbsent:
          {
            var key = m[3];
            var putValue = m[4];
            response = putIfAbsent(key, putValue);
          }
        case SharedMapOperation.remove:
          {
            var key = m[3];
            response = remove(key);
          }
        case SharedMapOperation.removeAll:
          {
            var keys = m[3] as List<K>;
            response = removeAll(keys);
          }
        case SharedMapOperation.keys:
          {
            response = keys();
          }
        case SharedMapOperation.allValues:
          {
            response = values();
          }
        case SharedMapOperation.entries:
          {
            response = entries();
          }
        case SharedMapOperation.length:
          {
            response = length();
          }
        case SharedMapOperation.clear:
          {
            response = clear();
          }
        case SharedMapOperation.where:
          {
            var test = m[3];
            response = where(test);
          }
      }

      clientPort.send([messageID, response]);
      return;
    }

    throw StateError("Unknown message type: $m");
  }

  @override
  V? get(K key) => _entries[key];

  @override
  V? put(K key, V? value) {
    if (value == null) {
      _entries.remove(key);
      return null;
    }
    _entries[key] = value;

    final onPut = this.onPut;
    if (onPut != null) {
      onPut(key, value);
    }

    return value;
  }

  @override
  V? putIfAbsent(K key, V? absentValue) {
    var prev = _entries[key];
    if (prev == null) {
      if (absentValue == null) {
        return null;
      }

      _entries[key] = absentValue;

      final onPut = this.onPut;
      if (onPut != null) {
        onPut(key, absentValue);
      }

      return absentValue;
    } else {
      return prev;
    }
  }

  @override
  V? remove(K key) {
    var v = _entries.remove(key);
    if (v != null) {
      final onRemove = this.onRemove;
      if (onRemove != null) {
        onRemove(key, v);
      }
    }
    return v;
  }

  @override
  List<V?> removeAll(List<K> keys) =>
      keys.map((k) => _entries.remove(k)).toList();

  @override
  List<K> keys() => _entries.keys.toList();

  @override
  List<V> values() => _entries.values.toList();

  @override
  List<MapEntry<K, V>> entries() => _entries.entries.toList();

  @override
  List<MapEntry<K, V>> where(bool Function(K key, V value) test) =>
      _entries.entries.where((e) => test(e.key, e.value)).toList();

  @override
  int length() => _entries.length;

  @override
  int clear() {
    var lng = _entries.length;

    List<MapEntry<K, V>>? removedEntries;

    final onRemove = this.onRemove;
    if (onRemove != null) {
      removedEntries = _entries.entries.toList();
    }

    _entries.clear();

    if (onRemove != null) {
      for (var e in removedEntries!) {
        onRemove(e.key, e.value);
      }
    }

    return lng;
  }

  late final generic.SharedMapCacheGeneric<K, V> _cached =
      generic.SharedMapCacheGeneric<K, V>(this);

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => _cached;

  @override
  SharedMapReferenceIsolate sharedReference() => SharedMapReferenceIsolate(
      id, sharedStore.sharedReference(), _receivePort.sendPort);

  @override
  String toString() =>
      'SharedMapIsolateServer[$id@${sharedStore.id}]{entries: ${_entries.length}';
}

class SharedMapIsolateClient<K, V> extends SharedMapIsolate<K, V>
    implements SharedMap<K, V> {
  final SendPort _serverPort;

  SharedMapIsolateClient(super.sharedStore, super.id, this._serverPort);

  int _msgIDCounter = 0;

  final Map<int, Completer> _waitingResponse = {};

  @override
  void _onReceiveMessage(m) {
    if (m is List) {
      var messageID = m[0] as int;
      var response = m[1];

      var completer = _waitingResponse.remove(messageID);

      if (completer != null && !completer.isCompleted) {
        completer.complete(response);
      }

      return;
    }

    throw StateError("Unknown message type: $m");
  }

  (int, Completer<T>) _newMsg<T>() {
    var msgID = ++_msgIDCounter;
    var completer = _waitingResponse[msgID] = Completer<T>();
    return (msgID, completer);
  }

  @override
  Future<V?> get(K key) async {
    var (msgID, completer) = _newMsg<V?>();

    _serverPort
        .send([SharedMapOperation.get, _receivePort.sendPort, msgID, key]);

    return completer.future;
  }

  @override
  Future<V?> put(K key, V? value) {
    var (msgID, completer) = _newMsg<V?>();

    _serverPort.send(
        [SharedMapOperation.put, _receivePort.sendPort, msgID, key, value]);

    return completer.future;
  }

  @override
  Future<V?> putIfAbsent(K key, V? absentValue) {
    var (msgID, completer) = _newMsg<V?>();

    _serverPort.send([
      SharedMapOperation.putIfAbsent,
      _receivePort.sendPort,
      msgID,
      key,
      absentValue
    ]);

    return completer.future;
  }

  @override
  Future<V?> remove(K key) {
    var (msgID, completer) = _newMsg<V?>();

    _serverPort
        .send([SharedMapOperation.remove, _receivePort.sendPort, msgID, key]);

    return completer.future;
  }

  @override
  Future<List<V?>> removeAll(List<K> keys) {
    var (msgID, completer) = _newMsg<List<V?>>();

    _serverPort.send(
        [SharedMapOperation.removeAll, _receivePort.sendPort, msgID, keys]);

    return completer.future;
  }

  @override
  Future<List<K>> keys() {
    var (msgID, completer) = _newMsg<List<K>>();

    _serverPort.send([SharedMapOperation.keys, _receivePort.sendPort, msgID]);

    return completer.future;
  }

  @override
  Future<List<V>> values() {
    var (msgID, completer) = _newMsg<List<V>>();

    _serverPort
        .send([SharedMapOperation.allValues, _receivePort.sendPort, msgID]);

    return completer.future;
  }

  @override
  Future<List<MapEntry<K, V>>> entries() {
    var (msgID, completer) = _newMsg<List<MapEntry<K, V>>>();

    _serverPort
        .send([SharedMapOperation.entries, _receivePort.sendPort, msgID]);

    return completer.future;
  }

  @override
  Future<List<MapEntry<K, V>>> where(bool Function(K key, V value) test) {
    var (msgID, completer) = _newMsg<List<MapEntry<K, V>>>();

    _serverPort
        .send([SharedMapOperation.where, _receivePort.sendPort, msgID, test]);

    return completer.future;
  }

  @override
  Future<int> length() {
    var (msgID, completer) = _newMsg<int>();

    _serverPort.send([SharedMapOperation.length, _receivePort.sendPort, msgID]);

    return completer.future;
  }

  @override
  Future<int> clear() {
    var (msgID, completer) = _newMsg<int>();

    _serverPort.send([SharedMapOperation.clear, _receivePort.sendPort, msgID]);

    return completer.future;
  }

  final Expando<SharedMapCached<K, V>> _cached = Expando();

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) {
    timeout ??= SharedMapCached.defaultTimeout;
    return _cached[timeout] ??= SharedMapCached<K, V>(this, timeout: timeout);
  }

  @override
  SharedMapReference sharedReference() =>
      SharedMapReferenceIsolate(id, sharedStore.sharedReference(), _serverPort);

  @override
  String toString() => 'SharedMapIsolateClient[$id@${sharedStore.id}]';
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

SharedStoreReference createSharedStoreReference({Map<String, dynamic>? json}) {
  var id = json!['id'];
  var sharedStore = createSharedStore(id: id);
  return sharedStore.sharedReference();
}

SharedMapReference createSharedMapReference({Map<String, dynamic>? json}) {
  var id = json!['id'];
  var sharedMap = createSharedMap(id: id);
  return sharedMap.sharedReference();
}

SharedStore createSharedStore(
    {String? id, SharedStoreReference? sharedReference}) {
  if (sharedReference != null) {
    id ??= sharedReference.id;

    var prev = SharedStoreIsolate._instances[id]?.target;

    if (sharedReference is SharedStoreReferenceIsolate) {
      if (prev != null) {
        if (prev is SharedStoreIsolateServer) {
          if (prev.sharedReference()._serverPort ==
              sharedReference._serverPort) {
            return prev;
          }
        } else if (prev is SharedStoreIsolateClient) {
          return prev;
        }
      }

      return SharedStoreIsolateClient(id, sharedReference._serverPort);
    } else {
      if (prev != null) return prev;

      if (sharedReference is generic.SharedStoreReferenceGeneric) {
        return generic.createSharedStore(sharedReference: sharedReference);
      }
    }

    throw StateError(
        "Unexpected `SharedStoreReference` type: $sharedReference");
  } else {
    var prev = SharedStoreIsolate._instances[id!]?.target;
    if (prev != null) return prev;

    return SharedStoreIsolateServer(id);
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
    } else if (sharedReference is generic.SharedMapReferenceGeneric) {
      return generic.createSharedMap(
          sharedStore: sharedStore, id: id, sharedReference: sharedReference);
    }
  } else if (sharedStore is SharedStoreIsolate) {
    var sharedMap = sharedStore._sharedMaps[id!] ??=
        SharedMapIsolateServer<K, V>(sharedStore, id);
    return sharedMap as SharedMap<K, V>;
  }

  throw StateError("Unexpected `SharedMapReference` type: $sharedReference");
}
