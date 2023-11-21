import 'dart:async';
import 'dart:math' as math;

import 'not_shared_map.dart';
import 'shared_map_cached.dart';
import 'shared_map_generic.dart'
    if (dart.library.isolate) 'shared_map_isolate.dart';

/// Base class for [SharedStore] and [SharedMap] implementations.
abstract class SharedType {
  static int _uuidCount = 0;

  /// Creates an UUID (Universally Unique Identifier).
  /// See [SharedStore.fromUUID] and [SharedMap.fromUUID].
  static String newUUID() {
    var c = ++_uuidCount;
    var now = DateTime.now();

    const range = 1999999999;

    var rand1 = math.Random();
    var rand2 = math.Random(now.microsecondsSinceEpoch);

    var seed3 = (rand1.nextInt(range) ^ rand2.nextInt(range)).abs() ^ c;
    var rand3 = math.Random(seed3);

    var n1 = rand1.nextInt(range);
    var n2 = rand2.nextInt(range);
    var n3 = rand3.nextInt(range);

    var n4 = (rand1.nextInt(range) ^ rand2.nextInt(range)).abs();
    var n5 = (rand1.nextInt(range) ^ rand3.nextInt(range)).abs();
    var n6 = (rand2.nextInt(range) ^ rand3.nextInt(range)).abs();

    return 'UUID-$n1-$n2-$n3-$n4-$n5-$n6-$c';
  }

  /// The ID of the shared instance.
  String get id;

  /// Returns the [SharedReference] of this instances, to instantiated it
  /// using `fromSharedReference` constructor.
  SharedReference sharedReference();
}

typedef SharedStoreProvider = FutureOr<SharedStore?> Function(String id);
typedef SharedStoreProviderSync = SharedStore? Function(String id);

/// Base class for [SharedStore] implementations.
abstract class SharedStore extends SharedType {
  /// Creates a [SharedStore] with [id].
  factory SharedStore(String id) {
    return createSharedStore(id: id);
  }

  /// Creates a [SharedStore] using a [SharedType.newUUID] as [id].
  factory SharedStore.fromUUID() => SharedStore(SharedType.newUUID());

  /// Creates a [SharedStore] that can NOT be shared.
  /// Useful for tests or to have a version that disables the share capabilities.
  factory SharedStore.notShared() => NotSharedStore();

  /// Creates a [SharedStore] from [sharedReference].
  factory SharedStore.fromSharedReference(
      SharedStoreReference sharedReference) {
    return createSharedStore(sharedReference: sharedReference);
  }

  /// Returns a [SharedMap] with [id] in this [SharedStore] instance.
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(String id);

  @override
  SharedStoreReference sharedReference();
}

/// The operations that a [SharedMap] performs.
///
/// Used by the `Isolate` implementation of [SharedMap].
enum SharedMapOperation {
  get,
  put,
  putIfAbsent,
  remove,
  removeAll,
  keys,
  allValues,
  length,
  clear,
}

/// Base class for [SharedMap] implementations.
abstract class SharedMap<K, V> extends SharedType {
  /// Creates a [SharedMap] with [id].
  factory SharedMap(SharedStore sharedStore, String id) {
    return createSharedMap(sharedStore: sharedStore, id: id);
  }

  /// Creates a [SharedMap] using a [SharedType.newUUID] as [id].
  factory SharedMap.fromUUID(SharedStore sharedStore) =>
      SharedMap(sharedStore, SharedType.newUUID());

  /// Creates a [SharedMap] that can NOT be shared.
  /// Useful for tests or to have a version that disables the share capabilities.
  factory SharedMap.notShared() => NotSharedMap();

  /// Creates a [SharedMap] from [sharedReference].
  factory SharedMap.fromSharedReference(SharedMapReference sharedReference) {
    return createSharedMap(sharedReference: sharedReference);
  }

  /// The [SharedStore] where this instance is stored/handled.
  SharedStore get sharedStore;

  /// Returns the value of [key].
  FutureOr<V?> get(K key);

  /// Sets the [value] of [key] and returns it.
  FutureOr<V?> put(K key, V? value);

  /// Sets the [absentValue] of [key] if it's `null`, and returns it.
  /// If the [key] value is already define and is NOT `null`,
  /// returns the previous value.
  FutureOr<V?> putIfAbsent(K key, V? absentValue);

  /// Remove the [key] entry and return the removed value.
  FutureOr<V?> remove(K key);

  /// Remove the [keys] entries and return the removed values.
  FutureOr<List<V?>> removeAll(List<K> keys);

  /// Returns all the keys.
  FutureOr<List<K>> keys();

  /// Returns all the values.
  FutureOr<List<V>> values();

  /// Returns [keys] length.
  FutureOr<int> length();

  /// Clears all the entries and returns the amount of removed entries.
  FutureOr<int> clear();

  @override
  SharedMapReference sharedReference();

  /// Returns a cached version of this instance.
  SharedMapCached<K, V> cached({Duration? timeout});
}

/// Synchronized version of a [SharedMap] implementation.
abstract class SharedMapSync<K, V> implements SharedMap<K, V> {
  @override
  V? get(K key);

  @override
  V? put(K key, V? value);

  @override
  V? putIfAbsent(K key, V? absentValue);

  @override
  V? remove(K key);

  @override
  List<V?> removeAll(List<K> keys);

  @override
  List<K> keys();

  @override
  List<V> values();

  @override
  int length();

  @override
  int clear();

  @override
  SharedMapReference sharedReference();

  /// Returns a cached version of this instance.
  ///
  /// Note that [SharedMapSync] implementations could return a fake cache
  /// implementation (not cached), as a [SharedMapSync] instance could be the
  /// primary instance responsible for storing entries.
  @override
  SharedMapCached<K, V> cached({Duration? timeout});
}

/// Base class for [SharedReference] implementations.
abstract class SharedReference {
  /// The ID of the referenced instance.
  final String id;

  SharedReference(this.id);

  /// The JSON of this [SharedReference].
  Map<String, dynamic> toJson();
}

/// Shared reference to a [SharedStore].
abstract class SharedStoreReference extends SharedReference {
  SharedStoreReference(super.id);

  factory SharedStoreReference.fromJson(Map<String, dynamic> json) {
    return createSharedStoreReference(json: json);
  }

  @override
  Map<String, dynamic> toJson() => {'id': id};

  @override
  String toString() => 'SharedStoreReference${toJson()}';
}

/// Shared reference to a [SharedMap].
abstract class SharedMapReference extends SharedReference {
  /// The [SharedStoreReference] of the [SharedStore] of the referenced [SharedMap].
  final SharedStoreReference sharedStoreReference;

  SharedMapReference(super.id, this.sharedStoreReference);

  factory SharedMapReference.fromJson(Map<String, dynamic> json) {
    return createSharedMapReference(json: json);
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'sharedStore': sharedStoreReference.toJson(),
      };

  @override
  String toString() => 'SharedMapReference${toJson()}';
}

/// Base class for objects that can be copied and passed to other `Isolate`s,
/// and automatically detected if it's a copied version ([isIsolateCopy]).
abstract class SharedObject {
  SharedObject();

  bool _isolateCopy = false;

  /// Returns `true` if this instance is a copy passed to another `Isolate`.
  bool get isIsolateCopy => _isolateCopy;
}

/// A [SharedStore] field/wrapper. This will handle the [SharedStore] in.
class SharedStoreField extends SharedObject {
  static final Map<String, WeakReference<SharedStoreField>> _instances = {};

  static SharedStoreField? _getInstanceByID(String id) {
    var ref = _instances[id];

    if (ref != null) {
      var prev = ref.target;
      if (prev != null) {
        return prev;
      } else {
        _instances.remove(id);
      }
    }

    return null;
  }

  factory SharedStoreField(String sharedStoreID) {
    var ref = _instances[sharedStoreID];
    if (ref != null) {
      var o = ref.target;
      if (o != null) return o;
    }

    var o = SharedStoreField._(sharedStoreID);
    assert(identical(o, _instances[sharedStoreID]?.target));
    return o;
  }

  factory SharedStoreField.fromSharedStore(SharedStore sharedStore) {
    if (sharedStore is NotSharedStore) {
      return NotSharedStoreField(sharedStore);
    }

    var o = SharedStoreField(sharedStore.id);
    if (!identical(sharedStore, o.sharedStore)) {
      throw StateError(
          "Parameter `sharedStore` instance is NOT the same of `SharedStoreField.sharedStore`> $sharedStore != ${o.sharedStore}");
    }
    return o;
  }

  factory SharedStoreField.from(
      {SharedStoreField? sharedStoreField,
      SharedStoreReference? sharedStoreReference,
      SharedStore? sharedStore,
      String? sharedStoreID,
      SharedStoreProviderSync? storeProvider}) {
    return tryFrom(
            sharedStoreField: sharedStoreField,
            sharedStoreReference: sharedStoreReference,
            sharedStore: sharedStore,
            sharedStoreID: sharedStoreID,
            storeProvider: storeProvider) ??
        (throw ArgumentError(
            "Null `sharedStoreField`, `sharedStore` and `sharedStoreID`. Please provide one of them."));
  }

  static SharedStoreField? tryFrom(
      {SharedStoreField? sharedStoreField,
      SharedStoreReference? sharedStoreReference,
      SharedStore? sharedStore,
      String? sharedStoreID,
      SharedStoreProviderSync? storeProvider}) {
    if (sharedStoreField != null) {
      return sharedStoreField;
    }

    if (sharedStoreReference != null) {
      if (sharedStoreReference is NotSharedStoreReference) {
        sharedStore ??= sharedStoreReference.notSharedStore;
      } else {
        sharedStore ??= SharedStore.fromSharedReference(sharedStoreReference);
      }
    }

    if (sharedStore != null) {
      return SharedStoreField.fromSharedStore(sharedStore);
    }

    if (sharedStoreID != null) {
      if (storeProvider != null) {
        var sharedStore = storeProvider(sharedStoreID);
        if (sharedStore != null) {
          return SharedStoreField.fromSharedStore(sharedStore);
        }
      }

      return SharedStoreField(sharedStoreID);
    }

    return null;
  }

  /// The global ID of the [sharedStore].
  final String sharedStoreID;

  SharedStoreField._(this.sharedStoreID) {
    _setupInstanceFromConstructor();
  }

  static final Expando<SharedStore> _sharedStoreExpando = Expando();
  SharedStoreReference? _sharedStoreReference;

  void _setupInstanceFromConstructor() {
    assert(_sharedStoreExpando[this] == null);

    final sharedStoreID = this.sharedStoreID;
    assert(_getInstanceByID(sharedStoreID) == null);

    var sharedStore = _sharedStoreExpando[this] = SharedStore(sharedStoreID);
    _sharedStoreReference = sharedStore.sharedReference();

    _instances[sharedStoreID] = WeakReference(this);
  }

  void _setupInstance() {
    var prev = _getInstanceByID(sharedStoreID);
    if (prev != null) {
      if (identical(prev, this)) {
        return;
      } else {
        throw StateError(
            "Previous `SharedStore` instance (id: $sharedStoreID) NOT identical to this instance: $prev != $this");
      }
    }

    return _setupInstanceIsolateCopy();
  }

  void _setupInstanceIsolateCopy() {
    assert(_sharedStoreExpando[this] == null);

    _isolateCopy = true;

    var sharedStoreReference = _sharedStoreReference ??
        (throw StateError(
            "An Isolate copy should have `_sharedStoreReference` defined!"));

    var sharedStore = SharedStore.fromSharedReference(sharedStoreReference);
    _sharedStoreExpando[this] = sharedStore;

    _instances[sharedStoreID] = WeakReference(this);
  }

  /// The [SharedStore] of this instance. This [SharedStore] will be
  /// automatically shared among `Isolate` copies.
  ///
  /// See [isIsolateCopy].
  SharedStore get sharedStore {
    _setupInstance();

    var sharedStored = _sharedStoreExpando[this];
    if (sharedStored == null) {
      throw StateError(
          "After `_setupInstance` `sharedStored` should be defined at `_sharedStoreExpando`");
    }

    return sharedStored;
  }

  @override
  String toString() =>
      'SharedStoreField#$sharedStoreID${isIsolateCopy ? '(Isolate copy)' : ''}';
}

class SharedMapField<K, V> extends SharedObject {
  factory SharedMapField.fromSharedMap(SharedMap<K, V> sharedMap) {
    if (sharedMap is NotSharedMap) {
      return NotSharedMapField(sharedMap as NotSharedMap<K, V>);
    }

    var o =
        SharedMapField<K, V>(sharedMap.id, sharedStore: sharedMap.sharedStore);
    if (!identical(sharedMap, o.sharedMap)) {
      throw StateError(
          "Parameter `sharedMap` instance is NOT the same of `SharedMapField.sharedMap`> $sharedMap != ${o.sharedMap}");
    }
    return o;
  }

  factory SharedMapField.from(
      {SharedMapField<K, V>? sharedMapField,
      SharedMapReference? sharedMapReference,
      SharedMap<K, V>? sharedMap,
      String? sharedMapID,
      SharedStoreField? sharedStoreField,
      SharedStore? sharedStore,
      String? sharedStoreID}) {
    if (sharedMapField != null) {
      return sharedMapField;
    }

    if (sharedMapReference != null) {
      if (sharedMapReference is NotSharedMapReference) {
        sharedMap = sharedMapReference.notSharedMap as NotSharedMap<K, V>;
      } else {
        sharedMap ??= SharedMap<K, V>.fromSharedReference(sharedMapReference);
      }
    }

    if (sharedMap != null) {
      return SharedMapField.fromSharedMap(sharedMap);
    }

    if (sharedMapID != null) {
      return SharedMapField(sharedMapID,
          sharedStoreField: sharedStoreField,
          sharedStore: sharedStore,
          sharedStoreID: sharedStoreID);
    }

    throw ArgumentError(
        "Null `sharedMapField`, `sharedMap` and `sharedMapID`. Please provide one of them.");
  }

  final SharedStoreField _sharedStoreField;

  /// The global ID of the [sharedMap].
  final String sharedMapID;

  SharedMapField(this.sharedMapID,
      {SharedStoreField? sharedStoreField,
      SharedStoreReference? sharedStoreReference,
      SharedStore? sharedStore,
      String? sharedStoreID})
      : _sharedStoreField = SharedStoreField.from(
            sharedStoreField: sharedStoreField,
            sharedStoreReference: sharedStoreReference,
            sharedStore: sharedStore,
            sharedStoreID: sharedStoreID) {
    _setupInstanceFromConstructor();
  }

  SharedStore get sharedStore => _sharedStoreField.sharedStore;

  static final Expando<SharedMap> _sharedMapExpando = Expando();

  SharedMapReference? _sharedMapReference;
  Future<SharedMap<K, V>>? _resolvingSharedMap;

  void _setupInstanceFromConstructor() {
    assert(_sharedMapExpando[this] == null);
    _resolveSharedMapFromStore();
  }

  FutureOr<SharedMap<K, V>> _setupInstance() {
    var sharedMap = _sharedMapExpando[this] as SharedMap<K, V>?;
    if (sharedMap != null) return sharedMap;

    return _setupInstanceIsolateCopy();
  }

  FutureOr<SharedMap<K, V>> _setupInstanceIsolateCopy() {
    assert(_sharedMapExpando[this] == null);

    _isolateCopy = true;

    var sharedMapReference = _sharedMapReference;

    if (sharedMapReference != null) {
      var sharedMap = SharedMap<K, V>.fromSharedReference(sharedMapReference);
      _sharedMapExpando[this] = sharedMap;
      return sharedMap;
    } else {
      return _resolveSharedMapFromStore();
    }
  }

  FutureOr<SharedMap<K, V>> _resolveSharedMapFromStore() {
    var resolvingSharedMap = _resolvingSharedMap;
    if (resolvingSharedMap != null) return resolvingSharedMap;

    final sharedStore = this.sharedStore;

    var sharedMapAsync = sharedStore.getSharedMap<K, V>(sharedMapID);

    if (sharedMapAsync is Future<SharedMap<K, V>?>) {
      return _resolvingSharedMap = sharedMapAsync.then((sharedMap) {
        sharedMap ??= SharedMap(sharedStore, sharedMapID);
        _sharedMapExpando[this] = sharedMap;
        _sharedMapReference = sharedMap.sharedReference();
        _resolvingSharedMap = null;
        return sharedMap;
      });
    } else {
      var sharedMap = sharedMapAsync ?? SharedMap(sharedStore, sharedMapID);
      _sharedMapExpando[this] = sharedMap;
      _sharedMapReference = sharedMap.sharedReference();
      return sharedMap;
    }
  }

  /// The [SharedMap] of this instance. This [SharedMap] will be
  /// automatically shared among `Isolate` copies.
  ///
  /// See [isIsolateCopy].
  FutureOr<SharedMap<K, V>> get sharedMap {
    var sharedMap = _setupInstance();
    return sharedMap;
  }

  /// Synchronized alias to [sharedMapSync].
  /// - Throws a [StateError] if [sharedMap] returns a [Future].
  SharedMap<K, V> get sharedMapSync {
    var sharedMap = this.sharedMap;
    if (sharedMap is! SharedMap<K, V>) {
      throw StateError(
          "`sharedMap` not resolved yet! Use the asynchronous getter `sharedMap`.");
    }
    return sharedMap;
  }

  /// Tries a synchronized resolution of [sharedMap] or returns `null`.
  SharedMap<K, V>? get trySharedMapSync {
    var sharedMap = this.sharedMap;
    if (sharedMap is! SharedMap<K, V>) {
      return null;
    }
    return sharedMap;
  }

  /// Returns a cached version of [sharedMap].
  /// See [SharedMap.cached].
  FutureOr<SharedMap<K, V>> sharedMapCached({Duration? timeout}) {
    var sharedMap = this.sharedMap;

    if (sharedMap is Future<SharedMap<K, V>>) {
      return sharedMap.then((sharedMap) => sharedMap.cached(timeout: timeout));
    } else {
      return sharedMap.cached(timeout: timeout);
    }
  }

  @override
  String toString() =>
      'SharedMapField#${_sharedStoreField.sharedStoreID}->$sharedMapID${isIsolateCopy ? '(Isolate copy)' : ''}';
}
