import 'dart:async';
import 'dart:isolate';

import 'not_shared_map.dart';
import 'shared_map_base.dart';
import 'shared_map_cached.dart';
import 'shared_map_generic.dart' as generic;
import 'shared_object_isolate.dart';

mixin _SharedStoreIsolate implements SharedStore {
  static final Map<String, WeakReference<_SharedStoreIsolate>> _instances = {};

  void _setupInstance() {
    var prev = _instances[id];
    if (identical(prev, this)) {
      return;
    }
    _instances[id] = WeakReference(this);
  }

  final Map<String, _SharedMapIsolate> _sharedMaps = {};
}

class _SharedStoreIsolateMain
    extends SharedObjectIsolateMain<SharedStoreReferenceIsolate>
    with _SharedStoreIsolate {
  _SharedStoreIsolateMain(String id) : super(id) {
    _setupInstance();
  }

  @override
  void onReceiveIsolateRequestMessage(SharedObjectIsolateRequestMessage m) {
    final args = m.args;

    var id = args[0] as String;
    var callCasted = args[1] as _CallCasted;

    var sharedMap =
        callCasted(<K1, V1>() => getSharedMap<K1, V1>(id)) as SharedMap?;

    m.sendResponse(sharedMap?.sharedReference());
  }

  @override
  SharedMap<K, V>? getSharedMap<K, V>(
    String id, {
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    var sharedMap = _sharedMaps[id];
    if (sharedMap != null) {
      if (sharedMap is! SharedMap<K, V>) {
        throw StateError(
            "[$this] Can't cast `sharedMap` to `SharedMap<$K, $V>`: $sharedMap");
      }
      return sharedMap as SharedMap<K, V>;
    }

    var o = createSharedMap<K, V>(sharedStore: this, id: id);

    o.setCallbacksDynamic<K, V>(onPut: onPut, onRemove: onRemove);

    return o;
  }

  @override
  SharedStoreReferenceIsolate sharedReference() =>
      SharedStoreReferenceIsolate(id, isolateSendPort);

  @override
  String toString() =>
      'SharedStoreIsolateMain[$id]{sharedMaps: ${_sharedMaps.length}}';
}

typedef _CallCasted<K, V> = Object? Function(Object? Function<K1, V1>() f);

class _SharedStoreIsolateAuxiliary
    extends SharedObjectIsolateAuxiliary<SharedStoreReferenceIsolate, dynamic>
    with _SharedStoreIsolate {
  @override
  final SendPort serverPort;

  _SharedStoreIsolateAuxiliary(super.id, this.serverPort) {
    _setupInstance();
  }

  @override
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(
    String id, {
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    var sharedMap = _sharedMaps[id];
    if (sharedMap != null) {
      var o = sharedMap as SharedMap<K, V>;
      o.setCallbacksDynamic<K, V>(onPut: onPut, onRemove: onRemove);
      return o;
    }

    _CallCasted<K, V> callCasted = _buildCallCasted<K, V>();

    return sendRequest<SharedMapReference>([id, callCasted]).then((ref) {
      if (ref == null) {
        throw StateError(
            "Can't get `SharedMapReference` from \"server\" instance: $id");
      }
      var o = createSharedMap<K, V>(sharedReference: ref);
      o.setCallbacksDynamic<K, V>(onPut: onPut, onRemove: onRemove);
      return o;
    });
  }

  /// Generates the lambda [Function] that will be passed to the
  /// [_SharedMapIsolateMain] to allow the correct casted call to [getSharedMap]`<K,V>()`.
  _CallCasted<K, V> _buildCallCasted<K, V>() => (f) => f<K, V>();

  @override
  SharedStoreReferenceIsolate sharedReference() =>
      SharedStoreReferenceIsolate(id, serverPort);

  @override
  String toString() =>
      'SharedStoreIsolateAuxiliary[$id]{sharedMaps: ${_sharedMaps.length}}';
}

mixin _SharedMapIsolate<K, V>
    implements SharedMap<K, V>, SharedObjectIsolate<SharedMapReferenceIsolate> {
  @override
  SharedMapEntryCallback<K, V>? onPut;

  @override
  SharedMapEntryCallback<K, V>? onRemove;

  @override
  void setCallbacks(
      {SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove}) {
    if (onPut != null) {
      this.onPut ??= onPut;
    }

    if (onRemove != null) {
      this.onRemove ??= onRemove;
    }
  }

  @override
  void setCallbacksDynamic<K1, V1>(
      {SharedMapEntryCallback<K1, V1>? onPut,
      SharedMapEntryCallback<K1, V1>? onRemove}) {
    if (onPut is SharedMapEntryCallback<K, V>) {
      this.onPut ??= onPut as SharedMapEntryCallback<K, V>;
    }

    if (onRemove is SharedMapEntryCallback<K, V>) {
      this.onRemove ??= onRemove as SharedMapEntryCallback<K, V>;
    }
  }
}

class _SharedMapIsolateMain<K, V>
    extends SharedObjectIsolateMain<SharedMapReferenceIsolate>
    with _SharedMapIsolate<K, V>
    implements SharedMapSync<K, V> {
  @override
  final SharedStore sharedStore;

  final Map<K, V> _entries;

  _SharedMapIsolateMain(this.sharedStore, super.id) : _entries = {};

  @override
  void onReceiveIsolateRequestMessage(SharedObjectIsolateRequestMessage m) {
    final args = m.args;

    final op = args[0] as SharedMapOperation;

    Object? response;

    switch (op) {
      case SharedMapOperation.get:
        {
          var key = args[1];
          response = get(key);
        }
      case SharedMapOperation.put:
        {
          var key = args[1];
          var putValue = args[2];
          response = put(key, putValue);
        }
      case SharedMapOperation.putIfAbsent:
        {
          var key = args[1];
          var putValue = args[2];
          response = putIfAbsent(key, putValue);
        }
      case SharedMapOperation.remove:
        {
          var key = args[1];
          response = remove(key);
        }
      case SharedMapOperation.removeAll:
        {
          var keys = args[1] as List<K>;
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
          var test = args[1];
          response = where(test);
        }
    }

    m.sendResponse(response);
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

    onPut.callback(key, value);

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

      onPut.callback(key, absentValue);

      return absentValue;
    } else {
      return prev;
    }
  }

  @override
  V? remove(K key) {
    var v = _entries.remove(key);
    if (v != null) {
      onRemove.callback(key, v);
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

    if (removedEntries != null) {
      onRemove!.callbackAll(removedEntries);
    }

    return lng;
  }

  late final generic.SharedMapCacheGeneric<K, V> _cached =
      generic.SharedMapCacheGeneric<K, V>(this);

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => _cached;

  @override
  SharedMapReferenceIsolate sharedReference() => SharedMapReferenceIsolate(
      id, sharedStore.sharedReference(), isolateSendPort);

  @override
  String toString() =>
      'SharedMapIsolateMain<$K,$V>[$id@${sharedStore.id}]{entries: ${_entries.length}}';
}

class _SharedMapIsolateAuxiliary<K, V>
    extends SharedObjectIsolateAuxiliary<SharedMapReferenceIsolate, dynamic>
    with _SharedMapIsolate<K, V> {
  @override
  final SharedStore sharedStore;
  @override
  final SendPort serverPort;

  _SharedMapIsolateAuxiliary(this.sharedStore, super.id, this.serverPort);

  @override
  Future<V?> get(K key) => sendRequest([SharedMapOperation.get, key]);

  @override
  Future<V?> put(K key, V? value) =>
      sendRequest([SharedMapOperation.put, key, value]);

  @override
  Future<V?> putIfAbsent(K key, V? absentValue) =>
      sendRequest([SharedMapOperation.putIfAbsent, key, absentValue]);

  @override
  Future<V?> remove(K key) => sendRequest([SharedMapOperation.remove, key]);

  @override
  Future<List<V?>> removeAll(List<K> keys) =>
      sendRequestNotNull<List<V?>>([SharedMapOperation.removeAll, keys]);

  @override
  Future<List<K>> keys() => sendRequestNotNull([SharedMapOperation.keys]);

  @override
  Future<List<V>> values() =>
      sendRequestNotNull([SharedMapOperation.allValues]);

  @override
  Future<List<MapEntry<K, V>>> entries() =>
      sendRequestNotNull([SharedMapOperation.entries]);

  @override
  Future<List<MapEntry<K, V>>> where(bool Function(K key, V value) test) =>
      sendRequestNotNull([SharedMapOperation.where, test]);

  @override
  Future<int> length() => sendRequestNotNull([SharedMapOperation.length]);

  @override
  Future<int> clear() => sendRequestNotNull([SharedMapOperation.clear]);

  final Expando<SharedMapCached<K, V>> _cached = Expando();

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) {
    timeout ??= SharedMapCached.defaultTimeout;
    return _cached[timeout] ??= SharedMapCached<K, V>(this, timeout: timeout);
  }

  @override
  SharedMapReferenceIsolate sharedReference() =>
      SharedMapReferenceIsolate(id, sharedStore.sharedReference(), serverPort);

  @override
  String toString() =>
      'SharedMapIsolateAuxiliary<$K,$V>[$id@${sharedStore.id}]';
}

class SharedStoreReferenceIsolate extends SharedStoreReference
    implements SharedReferenceIsolate {
  @override
  final SendPort serverPort;

  SharedStoreReferenceIsolate(super.id, this.serverPort);
}

class SharedMapReferenceIsolate extends SharedMapReference
    implements SharedReferenceIsolate {
  @override
  final SendPort serverPort;

  SharedMapReferenceIsolate(
      super.id, super.sharedStoreReference, this.serverPort);
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
    if (sharedReference is NotSharedStoreReference) {
      return sharedReference.notSharedStore;
    }

    id ??= sharedReference.id;

    var prev = _SharedStoreIsolate._instances[id]?.target;

    if (sharedReference is SharedStoreReferenceIsolate) {
      if (prev != null) {
        if (prev is _SharedStoreIsolateMain) {
          if (prev.sharedReference().serverPort == sharedReference.serverPort) {
            return prev;
          }
        } else if (prev is _SharedStoreIsolateAuxiliary) {
          return prev;
        }
      }

      return _SharedStoreIsolateAuxiliary(id, sharedReference.serverPort);
    } else {
      if (prev != null) return prev;

      if (sharedReference is generic.SharedStoreReferenceGeneric) {
        return generic.createSharedStore(sharedReference: sharedReference);
      }
    }

    throw StateError(
        "Unexpected `SharedStoreReference` type: $sharedReference");
  } else {
    var prev = _SharedStoreIsolate._instances[id!]?.target;
    if (prev != null) return prev;

    return _SharedStoreIsolateMain(id);
  }
}

SharedMap<K, V> createSharedMap<K, V>(
    {SharedStore? sharedStore,
    String? id,
    SharedMapReference? sharedReference}) {
  if (sharedReference != null) {
    if (sharedReference is NotSharedMapReference) {
      return sharedReference.notSharedMap as SharedMap<K, V>;
    } else if (sharedReference is SharedMapReferenceIsolate) {
      id ??= sharedReference.id;

      var sharedStoreReference =
          sharedReference.sharedStoreReference as SharedStoreReferenceIsolate;

      var sharedStoreID = sharedStoreReference.id;

      var sharedStore = _SharedStoreIsolate._instances[sharedStoreID]?.target ??
          _SharedStoreIsolateAuxiliary(
              sharedStoreID, sharedStoreReference.serverPort);

      var sharedMap = sharedStore._sharedMaps[id] ??=
          _SharedMapIsolateAuxiliary<K, V>(
              sharedStore, id, sharedReference.serverPort);
      return sharedMap as SharedMap<K, V>;
    } else if (sharedReference is generic.SharedMapReferenceGeneric) {
      return generic.createSharedMap(
          sharedStore: sharedStore, id: id, sharedReference: sharedReference);
    }
  } else if (sharedStore is _SharedStoreIsolate) {
    var sharedMap = sharedStore._sharedMaps[id!] ??=
        _SharedMapIsolateMain<K, V>(sharedStore, id);
    return sharedMap as SharedMap<K, V>;
  }

  if (id != null && sharedStore != null) {
    var sharedMap = sharedStore.getSharedMap<K, V>(id);
    if (sharedMap is SharedMap<K, V>) {
      return sharedMap;
    }

    throw StateError("Can't get `SharedMap<$K,$V>` with id: $id");
  }

  throw StateError("Unexpected `SharedMapReference` type: $sharedReference");
}
