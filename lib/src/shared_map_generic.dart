import 'dart:async';

import 'shared_map_base.dart';

class SharedStoreGeneric implements SharedStore {
  static final Map<String, WeakReference<SharedStore>> _instances = {};

  @override
  final String id;

  SharedStoreGeneric(this.id) {
    _instances[id] = WeakReference(this);
  }

  @override
  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(String id) {
    return createSharedMap(sharedStore: this, id: id);
  }

  @override
  SharedStoreReference shareReference() => SharedStoreReference(id);
}

class SharedMapGeneric<K, V> implements SharedMap<K, V> {
  @override
  final SharedStore sharedStore;

  @override
  final String id;

  final Map<K, V?> _entries;

  SharedMapGeneric(this.sharedStore, this.id) : _entries = {};

  @override
  FutureOr<V?> get(K key) {
    return _entries[key];
  }

  @override
  FutureOr<V?> put(K key, V? value) {
    return _entries[key] = value;
  }

  @override
  SharedMapReference shareReference() =>
      SharedMapReference(id, sharedStore.shareReference());
}

SharedStore createSharedStore(
    {String? id, SharedStoreReference? sharedReference}) {
  if (sharedReference != null) {
    id ??= sharedReference.id;
  }
  return SharedStoreGeneric(id!);
}

SharedMap<K, V> createSharedMap<K, V>(
    {SharedStore? sharedStore,
    String? id,
    SharedMapReference? sharedReference}) {
  if (sharedReference != null) {
    sharedStore ??= SharedStoreGeneric
        ._instances[sharedReference.sharedStoreReference.id]?.target;
    id ??= sharedReference.id;
  }
  return SharedMapGeneric(sharedStore!, id!);
}
