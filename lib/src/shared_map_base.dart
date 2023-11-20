import 'dart:async';

import 'shared_map_cached.dart';
import 'shared_map_generic.dart'
    if (dart.library.isolate) 'shared_map_isolate.dart';

/// Base class for [SharedStore] and [SharedMap] implementations.
abstract class SharedType {
  /// The ID of the shared instance.
  String get id;

  /// Returns the [SharedReference] of this instances, to instantiated it
  /// using `fromSharedReference` constructor.
  SharedReference sharedReference();
}

typedef SharedStoreProvider = FutureOr<SharedStore?> Function(String id);

/// Base class for [SharedStore] implementations.
abstract class SharedStore extends SharedType {
  /// Creates a [SharedStore] with [id].
  factory SharedStore(String id) {
    return createSharedStore(id: id);
  }

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
  length,
}

/// Base class for [SharedMap] implementations.
abstract class SharedMap<K, V> extends SharedType {
  /// Creates a [SharedMap] with [id].
  factory SharedMap(SharedStore sharedStore, String id) {
    return createSharedMap(sharedStore: sharedStore, id: id);
  }

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

  /// Returns [keys] length.
  FutureOr<int> length();

  @override
  SharedMapReference sharedReference();

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
