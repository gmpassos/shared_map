import 'dart:async';

import 'not_shared_map.dart';
import 'shared_map_cached.dart';
import 'shared_map_extension.dart';
import 'shared_map_generic.dart'
    if (dart.library.isolate) 'shared_map_isolate.dart';
import 'shared_map_generic.dart' as generic;
import 'shared_object.dart';
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
    SharedMapEventCallback? onInitialize,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  });

  /// Returns a shared object of type [t] or [O] with [id].
  /// The object should be previously registered with [registerSharedObject].
  /// See [getSharedObjectReference].
  FutureOr<O?> getSharedObject<O extends ReferenceableType>(String id,
      {Type? t});

  /// Returns a [SharedReference] [R] for type [t] or [O] with [id].
  /// The object should be previously registered with [registerSharedObject].
  /// See [getSharedObject].
  FutureOr<R?> getSharedObjectReference<O extends ReferenceableType,
      R extends SharedReference>(String id, {Type? t});

  /// Registers a shared object [o] (of type `[O]`). This object
  /// can be retrieved by [getSharedObject] and [getSharedObjectReference].
  void registerSharedObject<O extends ReferenceableType>(O o);

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
  update,
  remove,
  removeAll,
  keys,
  allValues,
  entries,
  length,
  clear,
  where,
}

typedef SharedMapEventCallback = void Function(SharedMap sharedMap);

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

typedef SharedMapUpdater<K, V> = V? Function(K key, V? value);

/// Base class for [SharedMap] implementations.
abstract class SharedMap<K, V> extends ReferenceableType {
  /// Creates a [SharedMap] with [id].
  static FutureOr<SharedMap<K, V>> fromID<K, V>(
      SharedStore sharedStore, String id,
      {SharedMapEventCallback? onInitialize,
      SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove}) {
    return createSharedMapAsync<K, V>(sharedStore: sharedStore, id: id)
        .setCallbacks(
      onInitialize: onInitialize,
      onPut: onPut,
      onRemove: onRemove,
    );
  }

  /// Creates a [SharedMap] using a [ReferenceableType.newUUID] as [id].
  static FutureOr<SharedMap<K, V>> fromUUID<K, V>(SharedStore sharedStore) =>
      SharedMap.fromID(sharedStore, ReferenceableType.newUUID());

  /// Creates a [SharedMap] that can NOT be shared.
  /// Useful for tests or to have a version that disables the share capabilities.
  factory SharedMap.notShared() => NotSharedMap();

  /// Creates a [SharedMap] from [sharedReference].
  factory SharedMap.fromSharedReference(SharedMapReference sharedReference) {
    return createSharedMap(sharedReference: sharedReference);
  }

  /// Creates a [SharedMap] from [reference] or [id].
  static FutureOr<SharedMap<K, V>> from<K, V>(
      {SharedMapReference? reference,
      String? id,
      SharedStoreReference? sharedStoreReference,
      SharedStore? sharedStore,
      String? sharedStoreID,
      SharedMapEventCallback? onInitialize,
      SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove}) {
    if (reference != null) {
      return SharedMap.fromSharedReference(reference)
        ..setCallbacks(
            onInitialize: onInitialize, onPut: onPut, onRemove: onRemove);
    }

    if (id != null) {
      sharedStore ??=
          SharedStore.from(reference: sharedStoreReference, id: sharedStoreID);
      return SharedMap.fromID(sharedStore, id,
          onInitialize: onInitialize, onPut: onPut, onRemove: onRemove);
    }

    throw MultiNullArguments(['reference', 'id']);
  }

  /// The [SharedStore] where this instance is stored/handled.
  SharedStore get sharedStore;

  /// Optional callback for when the [SharedMap] instance is initialized.
  ///
  /// - If running on the `Isolate` version, it will be triggered only on the "server" side.
  /// - Note: Ensure that the `onInitialize` callback is passed in the constructor
  ///   or to the [SharedStore.getSharedMap], and refrain from setting it after instance creation.
  SharedMapEventCallback? get onInitialize;

  set onInitialize(SharedMapEventCallback? callback);

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
      {SharedMapEventCallback? onInitialize,
      SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove});

  void setCallbacksDynamic<K1, V1>(
      {SharedMapEventCallback? onInitialize,
      SharedMapEntryCallback<K1, V1>? onPut,
      SharedMapEntryCallback<K1, V1>? onRemove});

  /// Returns the value of [key].
  FutureOr<V?> get(K key);

  /// Sets the [value] of [key] and returns it.
  FutureOr<V?> put(K key, V? value);

  /// Sets the [absentValue] of [key] if it's `null`, and returns it.
  /// If the [key] value is already define and is NOT `null`,
  /// returns the previous value.
  FutureOr<V?> putIfAbsent(K key, V? absentValue);

  /// Updated the [key] value by running the [updater] code in the
  /// same memory context (`Isolate`) as the main instance.
  ///
  /// - Note that if [updater] is a lambda/anonymous [Function],
  /// any object held by it will be passed through `Isolate`s.
  FutureOr<V?> update(K key, SharedMapUpdater<K, V> updater);

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

extension SharedMapExtension<K, V> on SharedMap<K, V>? {
  /// Alias to [SharedObject.isAuxiliaryInstance] if the [SharedMap] [isSharedObject].
  bool get isAuxiliaryInstance => asSharedObject?.isAuxiliaryInstance ?? false;

  /// Alias to [SharedObject.isMainInstance] if the [SharedMap] [isSharedObject].
  bool get isMainInstance => asSharedObject?.isMainInstance ?? false;

  /// Returns `true` if the [SharedMap] is a [SharedObject].
  /// See [asSharedObject].
  bool get isSharedObject => asSharedObject != null;

  /// Cast this [SharedMap] instance to a [SharedObject] if possible,
  /// otherwise, return `null`.
  SharedObject? get asSharedObject {
    var self = this;
    if (self is SharedObject) {
      var sharedObj = self as SharedObject;
      return sharedObj;
    }
    return null;
  }
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
  V? update(K key, SharedMapUpdater<K, V> updater);

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

class _SharedStoreFieldGeneric extends SharedStoreField {
  static final _instanceHandler = SharedFieldInstanceHandler<
      SharedStoreReference, SharedStore, SharedStoreField>(
    fieldInstantiator: _SharedStoreFieldGeneric._fromID,
    sharedObjectInstantiator: generic.SharedStoreGeneric.from,
    group: (generic.SharedStoreGeneric, null),
  );

  _SharedStoreFieldGeneric._fromID(super.sharedObjectID,
      {super.sharedObjectReference})
      : super._fromID(instanceHandler: _instanceHandler);

  @override
  SharedFieldInstanceHandler<SharedStoreReference, SharedStore,
      SharedStoreField> get instanceHandler => _instanceHandler;
}

/// A [SharedStore] field/wrapper. This will handle the [SharedStore] in.
class SharedStoreField extends SharedObjectField<SharedStoreReference,
    SharedStore, SharedStoreField> {
  static final _instanceHandler = SharedFieldInstanceHandler<
      SharedStoreReference, SharedStore, SharedStoreField>(
    fieldInstantiator: SharedStoreField._fromID,
    sharedObjectInstantiator: SharedStore.from,
  );

  SharedStoreField._fromID(super.sharedObjectID,
      {super.sharedObjectReference,
      SharedFieldInstanceHandler<SharedStoreReference, SharedStore,
              SharedStoreField>?
          instanceHandler})
      : super.fromID(instanceHandler: instanceHandler ?? _instanceHandler);

  factory SharedStoreField(String id) => _instanceHandler.fromID(id);

  factory SharedStoreField.fromSharedStore(SharedStore o) {
    if (o is NotSharedStore) {
      return NotSharedStoreField(o);
    } else if (o is generic.SharedStoreGeneric) {
      return _SharedStoreFieldGeneric._instanceHandler.fromSharedObject(o);
    }
    return _instanceHandler.fromSharedObject(o);
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

  @override
  SharedFieldInstanceHandler<SharedStoreReference, SharedStore,
      SharedStoreField> get instanceHandler => _instanceHandler;
}

/// A [SharedStore] field/wrapper. This will handle the [SharedStore] in.
class SharedMapField<K, V> extends SharedObjectField<SharedMapReference,
    SharedMap<K, V>, SharedMapField<K, V>> {
  /// Resolves the [SharedFieldInstanceHandler] for each [SharedStore] of [sharedStoreReference].
  static SharedFieldInstanceHandler<SharedMapReference, SharedMap<K, V>,
      SharedMapField<K, V>> _instanceHandler<K, V>(
    SharedStoreReference sharedStoreReference,
    SharedMapEventCallback? onInitialize,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  ) =>
      SharedFieldInstanceHandler(
        fieldInstantiator: (id, {sharedObjectReference}) =>
            SharedMapField._fromID(
                id,
                sharedObjectReference: sharedObjectReference,
                sharedStoreReference,
                onInitialize,
                onPut,
                onRemove),
        sharedObjectInstantiator: ({reference, id}) => SharedMap.from(
            reference: reference,
            id: id,
            sharedStoreReference: sharedStoreReference,
            onInitialize: onInitialize,
            onPut: onPut,
            onRemove: onRemove),
        group: (SharedStore, sharedStoreReference.id),
      );

  factory SharedMapField(
    String id, {
    SharedStore? sharedStore,
    SharedStoreReference? sharedStoreReference,
    String? sharedStoreID,
    SharedMapEventCallback? onInitialize,
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
              onInitialize,
              onPut,
              onRemove)
          .fromID(id);

  factory SharedMapField.fromSharedMap(SharedMap<K, V> o) {
    if (o is NotSharedMap<K, V>) {
      return NotSharedMapField<K, V>(o);
    }

    return _instanceHandler<K, V>(o.sharedStore.sharedReference(),
            o.onInitialize, o.onPut, o.onRemove)
        .fromSharedObject(o);
  }

  factory SharedMapField.from({
    SharedMapField<K, V>? sharedMapField,
    SharedMapReference? sharedMapReference,
    SharedMap<K, V>? sharedMap,
    String? sharedMapID,
    SharedStore? sharedStore,
    SharedStoreReference? sharedStoreReference,
    String? sharedStoreID,
    SharedMapEventCallback? onInitialize,
    SharedMapEntryCallback<K, V>? onPut,
    SharedMapEntryCallback<K, V>? onRemove,
  }) {
    return tryFrom(
            sharedMapField: sharedMapField,
            sharedMapReference: sharedMapReference,
            sharedMap: sharedMap,
            sharedMapID: sharedMapID,
            sharedStore: sharedStore,
            sharedStoreReference: sharedStoreReference,
            sharedStoreID: sharedStoreID,
            onInitialize: onInitialize,
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
    SharedMapEventCallback? onInitialize,
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
          onInitialize: onInitialize,
          onPut: onPut,
          onRemove: onRemove);
    }

    return null;
  }

  final SharedStoreField _sharedStoreField;

  SharedMapField._fromID(
      super.sharedObjectID,
      SharedStoreReference sharedStoreReference,
      SharedMapEventCallback? onInitialize,
      SharedMapEntryCallback<K, V>? onPut,
      SharedMapEntryCallback<K, V>? onRemove,
      {super.sharedObjectReference})
      : _sharedStoreField =
            SharedStoreField.from(sharedStoreReference: sharedStoreReference),
        super.fromID(
            instanceHandler: _instanceHandler(
                sharedStoreReference, onInitialize, onPut, onRemove));

  SharedStore get sharedStore => _sharedStoreField.sharedStore;

  @override
  String get runtimeTypeName => 'SharedMapField';

  String get sharedMapID => sharedObjectID;

  SharedMap<K, V> get sharedMap => sharedObject;

  FutureOr<SharedMap<K, V>> get sharedMapAsync => sharedObjectAsync;

  /// Returns a cached version of [sharedMap].
  /// See [SharedMap.cached].
  FutureOr<SharedMap<K, V>> sharedMapCached({Duration? timeout}) =>
      sharedMapAsync.cached(timeout: timeout);
}
