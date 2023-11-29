import 'dart:async';

import 'not_shared_map.dart';
import 'shared_map_cached.dart';
import 'shared_map_generic.dart'
    if (dart.library.isolate) 'shared_map_isolate.dart';
import 'shared_object_field.dart';
import 'shared_reference.dart';
import 'utils.dart';

typedef SharedStoreProvider = FutureOr<SharedStore?> Function(String id);
typedef SharedStoreProviderSync = SharedStore? Function(String id);

/// Base class for [SharedStore] implementations.
abstract class SharedStore extends ReferenceableType {
  /// Creates a [SharedStore] with [id].
  factory SharedStore(String id) {
    return createSharedStore(id: id);
  }

  /// Creates a [SharedStore] using a [ReferenceableType.newUUID] as [id].
  factory SharedStore.fromUUID() => SharedStore(ReferenceableType.newUUID());

  /// Creates a [SharedStore] that can NOT be shared.
  /// Useful for tests or to have a version that disables the share capabilities.
  factory SharedStore.notShared() => NotSharedStore();

  /// Creates a [SharedStore] from [sharedReference].
  factory SharedStore.fromSharedReference(
      SharedStoreReference sharedReference) {
    return createSharedStore(sharedReference: sharedReference);
  }

  /// Creates a [SharedStore] from [reference] or [id].
  factory SharedStore.from({SharedStoreReference? reference, String? id}) {
    if (reference != null) {
      return SharedStore.fromSharedReference(reference);
    }

    if (id != null) {
      return SharedStore(id);
    }

    throw MultiNullArguments(['reference', 'id']);
  }

  /// Returns a [SharedMap] with [id] in this [SharedStore] instance.
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(
    String id, {
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  });

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
  entries,
  length,
  clear,
  where,
}

typedef SharedMapEntryCallback<K, V> = void Function(K key, V? value);

extension SharedMapEntryCallbackExtension<K, V>
    on SharedMapEntryCallback<K, V>? {
  void callback<R>(K k, V v) {
    var f = this;
    if (f == null) return;
    f(k, v);
  }

  void callbackAll<R>(List<MapEntry<K, V>> entries) {
    var f = this;
    if (f == null) return;

    for (var e in entries) {
      f(e.key, e.value);
    }
  }
}

/// Base class for [SharedMap] implementations.
abstract class SharedMap<K, V> extends ReferenceableType {
  /// Creates a [SharedMap] with [id].
  factory SharedMap(SharedStore sharedStore, String id) {
    return createSharedMap(sharedStore: sharedStore, id: id);
  }

  /// Creates a [SharedMap] using a [ReferenceableType.newUUID] as [id].
  factory SharedMap.fromUUID(SharedStore sharedStore) =>
      SharedMap(sharedStore, ReferenceableType.newUUID());

  /// Creates a [SharedMap] that can NOT be shared.
  /// Useful for tests or to have a version that disables the share capabilities.
  factory SharedMap.notShared() => NotSharedMap();

  /// Creates a [SharedMap] from [sharedReference].
  factory SharedMap.fromSharedReference(SharedMapReference sharedReference) {
    return createSharedMap(sharedReference: sharedReference);
  }

  /// Creates a [SharedMap] from [reference] or [id].
  factory SharedMap.from(
      {SharedMapReference? reference,
      String? id,
      SharedStoreReference? sharedStoreReference,
      String? sharedStoreID}) {
    if (reference != null) {
      return SharedMap.fromSharedReference(reference);
    }

    if (id != null) {
      var store =
          SharedStore.from(reference: sharedStoreReference, id: sharedStoreID);
      return SharedMap(store, id);
    }

    throw MultiNullArguments(['reference', 'id']);
  }

  /// The [SharedStore] where this instance is stored/handled.
  SharedStore get sharedStore;

  /// Optional callback for when [put] is called.
  ///
  /// - If running on the `Isolate` version, it will be triggered only on the "server" side.
  SharedMapEntryCallback<K, V>? get onPut;

  set onPut(SharedMapEntryCallback<K, V>? callback);

  /// Optional callback for when [remove] is called.
  ///
  /// - If running on the `Isolate` version, it will be triggered only on the "server" side.
  SharedMapEntryCallback<K, V>? get onRemove;

  set onRemove(SharedMapEntryCallback<K, V>? callback);

  void setCallbacks(
      {SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove});

  void setCallbacksDynamic<K1, V1>(
      {SharedMapEntryCallback<K1, V1>? onPut,
      SharedMapEntryCallback<K1, V1>? onRemove});

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

  /// Returns all the entries.
  FutureOr<List<MapEntry<K, V>>> entries();

  /// Returns all the entries that satisfy the predicate [test].
  FutureOr<List<MapEntry<K, V>>> where(bool Function(K key, V value) test);

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
  List<MapEntry<K, V>> entries();

  @override
  List<MapEntry<K, V>> where(bool Function(K key, V value) test);

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

/// A [SharedStore] field/wrapper. This will handle the [SharedStore] in.
class SharedStoreField extends SharedObjectField<SharedStoreReference,
    SharedStore, SharedStoreField> {
  static final _instanceHandler = SharedFieldInstanceHandler<
      SharedStoreReference, SharedStore, SharedStoreField>(
    fieldInstantiator: SharedStoreField._fromID,
    sharedObjectInstantiator: SharedStore.from,
  );

  SharedStoreField._fromID(String id)
      : super.fromID(id, instanceHandler: _instanceHandler);

  factory SharedStoreField(String id) => _instanceHandler.fromID(id);

  factory SharedStoreField.fromSharedStore(SharedStore o) =>
      _instanceHandler.fromSharedObject(o);

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
        (throw MultiNullArguments([
          'sharedStoreField',
          'sharedStoreReference',
          'sharedStore',
          'sharedStoreID'
        ]));
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

  @override
  String get runtimeTypeName => 'SharedStoreField';

  String get sharedStoreID => sharedObjectID;

  SharedStore get sharedStore => sharedObject;
}

/// A [SharedStore] field/wrapper. This will handle the [SharedStore] in.
class SharedMapField<K, V> extends SharedObjectField<SharedMapReference,
    SharedMap<K, V>, SharedMapField<K, V>> {
  /// Resolves the [SharedFieldInstanceHandler] for each [SharedStore] of [sharedStoreReference].
  static SharedFieldInstanceHandler<SharedMapReference, SharedMap<K, V>,
      SharedMapField<K, V>> _instanceHandler<K, V>(
    SharedStoreReference sharedStoreReference,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  ) =>
      SharedFieldInstanceHandler(
        fieldInstantiator: (id) =>
            SharedMapField._fromID(id, sharedStoreReference, onPut, onRemove),
        sharedObjectInstantiator: ({reference, id}) => SharedMap.from(
            reference: reference,
            id: id,
            sharedStoreReference: sharedStoreReference)
          ..setCallbacks(onPut: onPut, onRemove: onRemove),
        group: sharedStoreReference.id,
      );

  final SharedStoreField _sharedStoreField;

  SharedMapField._fromID(
    String id,
    SharedStoreReference sharedStoreReference,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  )   : _sharedStoreField =
            SharedStoreField.from(sharedStoreReference: sharedStoreReference),
        super.fromID(id,
            instanceHandler:
                _instanceHandler(sharedStoreReference, onPut, onRemove));

  factory SharedMapField(
    String id, {
    SharedStore? sharedStore,
    SharedStoreReference? sharedStoreReference,
    String? sharedStoreID,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) =>
      _instanceHandler<K, V>(
              sharedStoreReference ??
                  sharedStore?.sharedReference() ??
                  (sharedStoreID != null
                      ? SharedStore(sharedStoreID).sharedReference()
                      : null) ??
                  (throw MultiNullArguments([
                    'sharedStore',
                    'sharedStoreReference',
                    'sharedStoreID'
                  ])),
              onPut,
              onRemove)
          .fromID(id);

  factory SharedMapField.fromSharedMap(SharedMap<K, V> o) =>
      _instanceHandler<K, V>(
              o.sharedStore.sharedReference(), o.onPut, o.onRemove)
          .fromSharedObject(o);

  factory SharedMapField.from({
    SharedMapField<K, V>? sharedMapField,
    SharedMapReference? sharedMapReference,
    SharedMap<K, V>? sharedMap,
    String? sharedMapID,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    return tryFrom(
            sharedMapField: sharedMapField,
            sharedMapReference: sharedMapReference,
            sharedMap: sharedMap,
            sharedMapID: sharedMapID,
            onPut: onPut,
            onRemove: onRemove) ??
        (throw MultiNullArguments(
            ['sharedStoreField', 'sharedStore', 'sharedStoreID']));
  }

  static SharedMapField<K, V>? tryFrom<K, V>({
    SharedMapField<K, V>? sharedMapField,
    SharedMapReference? sharedMapReference,
    SharedMap<K, V>? sharedMap,
    String? sharedMapID,
    SharedStore? sharedStore,
    SharedStoreReference? sharedStoreReference,
    String? sharedStoreID,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    if (sharedMapField != null) {
      return sharedMapField;
    }

    if (sharedMapReference != null) {
      if (sharedMapReference is NotSharedMapReference) {
        sharedMap ??= sharedMapReference.notSharedMap as SharedMap<K, V>;
      } else {
        sharedMap ??= SharedMap.fromSharedReference(sharedMapReference);
      }
    }

    if (sharedMap != null) {
      return SharedMapField.fromSharedMap(sharedMap);
    }

    if (sharedMapID != null) {
      return SharedMapField(sharedMapID,
          sharedStore: sharedStore,
          sharedStoreReference: sharedStoreReference,
          sharedStoreID: sharedStoreID,
          onPut: onPut,
          onRemove: onRemove);
    }

    return null;
  }

  SharedStore get sharedStore => _sharedStoreField.sharedStore;

  @override
  String get runtimeTypeName => 'SharedMapField';

  String get sharedMapID => sharedObjectID;

  SharedMap<K, V> get sharedMap => sharedObject;

  /// Returns a cached version of [sharedMap].
  /// See [SharedMap.cached].
  FutureOr<SharedMap<K, V>> sharedMapCached({Duration? timeout}) {
    var sharedMap = this.sharedMap;
    return sharedMap.cached(timeout: timeout);
  }
}
