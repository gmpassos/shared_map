import 'dart:async';
import 'dart:isolate';

import 'not_shared_map.dart';
import 'shared_map_base.dart';
import 'shared_map_cached.dart';
import 'shared_map_generic.dart' as generic;
import 'shared_object_isolate.dart';
import 'shared_reference.dart';

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

  final Map<Type, Map<String, WeakReference<ReferenceableType>>>
      _typesSharedObjects = {};

  @override
  O? getSharedObject<O extends ReferenceableType>(String id, {Type? t}) {
    t ??= O;
    var sharedObjects = _typesSharedObjects[t];
    if (sharedObjects == null || sharedObjects.isEmpty) return null;

    var ref = sharedObjects[id];

    if (ref != null) {
      var prev = ref.target;
      if (prev == null) {
        sharedObjects.remove(id);
      } else {
        return prev as O;
      }
    }

    return null;
  }

  @override
  void registerSharedObject<O extends ReferenceableType>(O o) {
    if (o is SharedMap) {
      throw StateError("Can't register a `SharedMap`: $o");
    }

    var sharedObjects = (_typesSharedObjects[O] ??=
        <String, WeakReference<O>>{}) as Map<String, WeakReference<O>>;

    var id = o.id;

    var ref = sharedObjects[id];
    if (ref != null) {
      var prev = ref.target;
      if (prev == null) {
        sharedObjects.remove(id);
      } else {
        if (identical(prev, o)) {
          return;
        }

        throw StateError(
            "Shared object (`$O`) with id `$id` already registered: $prev != $o");
      }
    }

    sharedObjects[id] = WeakReference<O>(o);
  }
}

enum _SharedStoreIsolateOperation {
  sharedPorts,
  getSharedMap,
  getSharedObjectReference,
}

class _SharedStoreIsolateMain
    extends SharedObjectIsolateMain<SharedStoreReferenceIsolate>
    with _SharedStoreIsolate {
  _SharedStoreIsolateMain(super.id) {
    _setupInstance();
  }

  @override
  void onReceiveIsolateRequestMessage(SharedObjectIsolateRequestMessage m) {
    final args = m.args;

    var op = args[0] as _SharedStoreIsolateOperation;

    switch (op) {
      case _SharedStoreIsolateOperation.sharedPorts:
        {
          _processSharedPorts(m);
        }
      case _SharedStoreIsolateOperation.getSharedMap:
        {
          _processGetSharedMap(m);
        }
      case _SharedStoreIsolateOperation.getSharedObjectReference:
        {
          _processGetSharedObjectReference(m);
        }
    }
  }

  void _processSharedPorts(SharedObjectIsolateRequestMessage m) {
    var sharedMapsPorts = _sharedMaps
        .map((id, o) => MapEntry(id, o.sharedReference().serverPort));

    var sharedObjectPorts = _typesSharedObjects.map((t, objs) {
      var typePorts = objs.map((id, ref) {
        var objRef = ref.target?.sharedReference();
        return MapEntry(id, objRef);
      });
      return MapEntry(t, typePorts);
    });

    m.sendResponse((sharedMapsPorts, sharedObjectPorts));
  }

  void _processGetSharedMap(SharedObjectIsolateRequestMessage m) {
    final args = m.args;

    var id = args[1] as String;
    var callCasted = args[2] as _CallCasted;

    var sharedMap =
        callCasted(<K1, V1>() => getSharedMap<K1, V1>(id)) as SharedMap?;

    m.sendResponse(sharedMap?.sharedReference());
  }

  void _processGetSharedObjectReference(SharedObjectIsolateRequestMessage m) {
    final args = m.args;

    var id = args[1] as String;
    var t = args[2] as Type;

    var ref = getSharedObjectReference(id, t: t);

    m.sendResponse(ref);
  }

  @override
  SharedMap<K, V>? getSharedMap<K, V>(
    String id, {
    SharedMapEventCallback? onInitialize,
    SharedMapKeyCallback<K, V>? onAbsent,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    var sharedMap = _sharedMaps[id];
    if (sharedMap != null) {
      if (sharedMap is! SharedMap<K, V>) {
        throw StateError(
            "[$this] Can't cast `sharedMap` to `SharedMap<$K, $V>`: $sharedMap");
      }

      sharedMap.setCallbacksDynamic<K, V>(
          onInitialize: onInitialize,
          onAbsent: onAbsent,
          onPut: onPut,
          onRemove: onRemove);

      return sharedMap as SharedMap<K, V>;
    }

    var o = createSharedMap<K, V>(sharedStore: this, id: id);

    o.setCallbacksDynamic<K, V>(
        onInitialize: onInitialize,
        onAbsent: onAbsent,
        onPut: onPut,
        onRemove: onRemove);

    return o;
  }

  void _registerSharedMap(_SharedMapIsolateMain sharedMap) {
    final id = sharedMap.id;
    _sharedMaps[id] = sharedMap;

    var sharedMapPort = sharedMap.sharedReference().serverPort;

    var ref = sharedReference();

    var prevPort = ref._sharedMapsPorts[id];
    assert(prevPort == null || identical(prevPort, sharedMapPort));

    ref._sharedMapsPorts[id] = sharedMapPort;
  }

  @override
  R? getSharedObjectReference<O extends ReferenceableType,
      R extends SharedReference>(String id, {Type? t}) {
    var o = getSharedObject<O>(id, t: t);
    return o?.sharedReference() as R?;
  }

  SharedStoreReferenceIsolate? _sharedReference;

  @override
  SharedStoreReferenceIsolate sharedReference() =>
      _sharedReference ??= SharedStoreReferenceIsolate(id, isolateSendPort);

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

  _SharedStoreIsolateAuxiliary(super.id,
      {SendPort? serverPort, SharedStoreReferenceIsolate? sharedReference})
      : serverPort = serverPort ?? sharedReference!.serverPort,
        _sharedReference = sharedReference {
    _setupInstance();
    _updateSharedPorts();
  }

  void _updateSharedPorts() {
    sendRequest<
        (
          Map<String, SendPort>,
          Map<Type, Map<String, SharedReference?>>
        )>([_SharedStoreIsolateOperation.sharedPorts]).then((ports) {
      if (ports == null) return;

      var sharedMapPorts = ports.$1;
      var sharedObjectsPorts = ports.$2;

      var ref = sharedReference();

      for (var e in sharedMapPorts.entries) {
        ref._sharedMapsPorts[e.key] = e.value;
      }

      for (var typeEntry in sharedObjectsPorts.entries) {
        var t = typeEntry.key;
        var typeRefs = ref._sharedObjectsReferences[t] ??= {};

        for (var e in typeEntry.value.entries) {
          var r = e.value;
          if (r != null) {
            typeRefs[e.key] = r;
          }
        }
      }
    });
  }

  @override
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(
    String id, {
    SharedMapEventCallback? onInitialize,
    SharedMapKeyCallback<K, V>? onAbsent,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    var sharedMap = _sharedMaps[id];
    if (sharedMap != null) {
      var o = sharedMap as SharedMap<K, V>;
      o.setCallbacksDynamic<K, V>(
          onInitialize: onInitialize,
          onAbsent: onAbsent,
          onPut: onPut,
          onRemove: onRemove);
      return o;
    }

    var sharedStoreReference = sharedReference();

    var sharedMapsPort = sharedStoreReference._sharedMapsPorts[id];

    if (sharedMapsPort != null) {
      var ref =
          SharedMapReferenceIsolate(id, sharedStoreReference, sharedMapsPort);
      return _resolveSharedMapFromReference(
          ref, onInitialize, onAbsent, onPut, onRemove);
    }

    _CallCasted<K, V> callCasted = _buildCallCasted<K, V>();

    return sendRequest<SharedMapReference>(
            [_SharedStoreIsolateOperation.getSharedMap, id, callCasted])
        .then((ref) => _resolveSharedMapFromReference(
            ref, onInitialize, onAbsent, onPut, onRemove));
  }

  FutureOr<SharedMap<K, V>> _resolveSharedMapFromReference<K, V>(
    SharedMapReference? ref,
    SharedMapEventCallback? onInitialize,
    SharedMapKeyCallback<K, V>? onAbsent,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  ) {
    if (ref == null) {
      throw StateError(
          "Can't get `SharedMapReference` from \"server\" instance: $id");
    }

    var o = createSharedMap<K, V>(sharedReference: ref);

    o.setCallbacksDynamic<K, V>(
        onInitialize: onInitialize,
        onAbsent: onAbsent,
        onPut: onPut,
        onRemove: onRemove);

    return o;
  }

  /// Generates the lambda [Function] that will be passed to the
  /// [_SharedMapIsolateMain] to allow the correct casted call to [getSharedMap]`<K,V>()`.
  _CallCasted<K, V> _buildCallCasted<K, V>() => (f) => f<K, V>();

  @override
  FutureOr<R?> getSharedObjectReference<O extends ReferenceableType,
      R extends SharedReference>(String id, {Type? t}) {
    t ??= O;

    var o = getSharedObject<O>(id, t: t);
    if (o != null) {
      return o.sharedReference() as R?;
    }

    var ref = sharedReference();

    var typeRefs = ref._sharedObjectsReferences[t];

    var objRef = typeRefs?[id];

    if (objRef is R) {
      return objRef;
    }

    return sendRequest<R>(
            [_SharedStoreIsolateOperation.getSharedObjectReference, id, t])
        .then((ref) {
      if (ref != null) {
        var typeRefs = _sharedReference?._sharedObjectsReferences[t!] ??= {};
        typeRefs?[id] ??= ref;
      }
      return ref;
    });
  }

  SharedStoreReferenceIsolate? _sharedReference;

  @override
  SharedStoreReferenceIsolate sharedReference() =>
      _sharedReference ??= SharedStoreReferenceIsolate(id, serverPort);

  @override
  String toString() =>
      'SharedStoreIsolateAuxiliary[$id]{sharedMaps: ${_sharedMaps.length}}';
}

mixin _SharedMapIsolate<K, V>
    implements SharedMap<K, V>, SharedObjectIsolate<SharedMapReferenceIsolate> {
  @override
  SharedMapEventCallback? onInitialize;

  @override
  SharedMapKeyCallback<K, V>? onAbsent;

  @override
  SharedMapEntryCallback<K, V>? onPut;

  @override
  SharedMapEntryCallback<K, V>? onRemove;

  @override
  FutureOr<SharedMap<K, V>> setCallbacks(
      {SharedMapEventCallback? onInitialize,
      SharedMapKeyCallback<K, V>? onAbsent,
      SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove}) {
    SharedMapEventCallback? callOnInitialize;
    if (onInitialize != null && this.onInitialize == null) {
      this.onInitialize = onInitialize;
      callOnInitialize = onInitialize;
    }

    if (onAbsent != null) {
      this.onAbsent ??= onAbsent;
    }

    if (onPut != null) {
      this.onPut ??= onPut;
    }

    if (onRemove != null) {
      this.onRemove ??= onRemove;
    }

    if (callOnInitialize != null) {
      var r = callOnInitialize(this);
      if (r is Future) {
        return r.then((_) => this);
      }
    }

    return this;
  }

  @override
  FutureOr<SharedMap<K1, V1>> setCallbacksDynamic<K1, V1>(
      {SharedMapEventCallback? onInitialize,
      SharedMapKeyCallback<K1, V1>? onAbsent,
      SharedMapEntryCallback<K1, V1>? onPut,
      SharedMapEntryCallback<K1, V1>? onRemove}) {
    SharedMapEventCallback? callOnInitialize;
    if (onInitialize != null && this.onInitialize == null) {
      this.onInitialize = onInitialize;
      callOnInitialize = onInitialize;
    }

    if (onAbsent is SharedMapKeyCallback<K, V>) {
      this.onAbsent ??= onAbsent as SharedMapKeyCallback<K, V>;
    }

    if (onPut is SharedMapEntryCallback<K, V>) {
      this.onPut ??= onPut as SharedMapEntryCallback<K, V>;
    }

    if (onRemove is SharedMapEntryCallback<K, V>) {
      this.onRemove ??= onRemove as SharedMapEntryCallback<K, V>;
    }

    if (callOnInitialize != null) {
      var r = callOnInitialize(this);
      if (r is Future) {
        return r.then((_) => this as SharedMap<K1, V1>);
      }
    }

    return this as SharedMap<K1, V1>;
  }
}

class _SharedMapIsolateMain<K, V>
    extends SharedObjectIsolateMain<SharedMapReferenceIsolate>
    with _SharedMapIsolate<K, V>
    implements SharedMapSync<K, V> {
  @override
  final _SharedStoreIsolateMain sharedStore;

  final Map<K, V> _entries;

  _SharedMapIsolateMain(this.sharedStore, super.id) : _entries = {} {
    sharedStore._registerSharedMap(this);
  }

  @override
  void onReceiveIsolateRequestMessage(SharedObjectIsolateRequestMessage m) {
    final args = m.args;

    final op = args[0] as SharedMapOperation;

    Object? response;

    switch (op) {
      case SharedMapOperation.get:
        {
          var key = args[1] as K;
          response = get(key);
        }
      case SharedMapOperation.put:
        {
          var key = args[1] as K;
          var putValue = args[2] as V?;
          response = put(key, putValue);
        }
      case SharedMapOperation.putIfAbsent:
        {
          var key = args[1] as K;
          var putValue = args[2] as V?;
          response = putIfAbsent(key, putValue);
        }
      case SharedMapOperation.update:
        {
          var key = args[1] as K;
          var updater = args[2];
          response = update(key, updater);
        }
      case SharedMapOperation.remove:
        {
          var key = args[1] as K;
          response = remove(key);
        }
      case SharedMapOperation.removeAll:
        {
          var list = args[1] as List;
          var keys = list is List<K> ? list : list.cast<K>();
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
  V? get(K key) {
    var value = _entries[key];

    if (value == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        value = onAbsent(key);
        if (value != null) {
          _entries[key] = value;
        }
      }
    }

    return value;
  }

  @override
  FutureOr<V?> put(K key, V? value) {
    if (value == null) {
      _entries.remove(key);
      return null;
    }

    _entries[key] = value;

    return onPut.callback(key, value);
  }

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) {
    var prev = _entries[key];

    if (prev == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        prev = onAbsent(key);
        if (prev != null) {
          _entries[key] = prev;
        }
      }
    }

    if (prev == null) {
      if (absentValue == null) {
        return null;
      }

      _entries[key] = absentValue;

      return onPut.callback(key, absentValue);
    } else {
      return prev;
    }
  }

  @override
  FutureOr<V?> update(K key, SharedMapUpdater<K, V> updater) {
    var prev = _entries[key];

    if (prev == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        prev = onAbsent(key);
        if (prev != null) {
          _entries[key] = prev;
        }
      }
    }

    var value = updater(key, prev);
    return put(key, value);
  }

  @override
  FutureOr<V?> remove(K key) {
    var v = _entries.remove(key);

    if (v == null) {
      var onAbsent = this.onAbsent;
      if (onAbsent != null) {
        v = onAbsent(key);
      }
    }

    if (v != null) {
      return onRemove.callback(key, v);
    }

    return v;
  }

  @override
  FutureOr<List<V?>> removeAll(List<K> keys) {
    var list = keys.map(remove).toList();

    if (list.every((e) => e is! Future)) {
      return list.cast<V?>();
    }

    var futures = list.map((e) => e is Future<V?> ? e : Future<V?>.value(e));

    return Future.wait(futures);
  }

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

  SharedMapReferenceIsolate? _sharedReference;

  @override
  SharedMapReferenceIsolate sharedReference() =>
      _sharedReference ??= SharedMapReferenceIsolate(
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
  Future<V?> update(K key, SharedMapUpdater<K, V> updater) =>
      sendRequest([SharedMapOperation.update, key, updater]);

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

  SharedMapReferenceIsolate? _sharedReference;

  @override
  SharedMapReferenceIsolate sharedReference() => _sharedReference ??=
      SharedMapReferenceIsolate(id, sharedStore.sharedReference(), serverPort);

  @override
  String toString() =>
      'SharedMapIsolateAuxiliary<$K,$V>[$id@${sharedStore.id}]';
}

class SharedStoreReferenceIsolate extends SharedStoreReference
    implements SharedReferenceIsolate {
  final Map<String, SendPort> _sharedMapsPorts = {};

  final Map<Type, Map<String, SharedReference>> _sharedObjectsReferences = {};

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

      return _SharedStoreIsolateAuxiliary(id, sharedReference: sharedReference);
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
  var sharedMap = createSharedMapAsync<K, V>(
      sharedStore: sharedStore, id: id, sharedReference: sharedReference);

  if (sharedMap is Future<SharedMap<K, V>>) {
    throw StateError("Async resolution of `SharedMap<$K,$V>`: $id");
  }

  return sharedMap;
}

FutureOr<SharedMap<K, V>> createSharedMapAsync<K, V>(
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
          _SharedStoreIsolateAuxiliary(sharedStoreID,
              sharedReference: sharedStoreReference);

      var sharedMap = sharedStore._sharedMaps[id] ??=
          _SharedMapIsolateAuxiliary<K, V>(
              sharedStore, id, sharedReference.serverPort);

      return sharedMap as SharedMap<K, V>;
    } else if (sharedReference is generic.SharedMapReferenceGeneric) {
      return generic.createSharedMap(
          sharedStore: sharedStore, id: id, sharedReference: sharedReference);
    }
  } else if (sharedStore is _SharedStoreIsolate) {
    SharedMap? sharedMap = sharedStore._sharedMaps[id!];

    if (sharedMap == null) {
      if (sharedStore is _SharedStoreIsolateMain) {
        sharedMap = _SharedMapIsolateMain<K, V>(sharedStore, id);
      } else if (sharedStore is _SharedStoreIsolateAuxiliary) {
        var sharedMapAsync = sharedStore.getSharedMap<K, V>(id);

        if (sharedMapAsync is SharedMap<K, V>?) {
          sharedMap = sharedMapAsync;
        } else {
          return sharedMapAsync.then((sharedMap) =>
              sharedMap ??
              (throw StateError(
                  "Can't get `SharedMap<$K,$V>` with id `$id` from: $sharedStore")));
        }
      }
    }

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
