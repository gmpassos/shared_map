import 'dart:async';

import 'shared_map_generic.dart'
    if (dart.library.isolate) 'shared_map_isolate.dart';

abstract class SharedType {
  String get id;

  SharedReference shareReference();
}

abstract class SharedStore extends SharedType {
  factory SharedStore(String id) {
    return createSharedStore(id: id);
  }

  factory SharedStore.fromSharedReference(
      SharedStoreReference sharedReference) {
    return createSharedStore(sharedReference: sharedReference);
  }

  FutureOr<SharedMap<K, V>?> getSharedMap<K, V>(String id);

  @override
  SharedStoreReference shareReference();
}

abstract class SharedMap<K, V> extends SharedType {
  factory SharedMap(SharedStore sharedStore, String id) {
    return createSharedMap(sharedStore: sharedStore, id: id);
  }

  factory SharedMap.fromSharedReference(SharedMapReference sharedReference) {
    return createSharedMap(sharedReference: sharedReference);
  }

  SharedStore get sharedStore;

  FutureOr<V?> get(K key);

  FutureOr<V?> put(K key, V? value);

  @override
  SharedMapReference shareReference();
}

abstract class SharedReference {
  Map<String, dynamic> toJson();
}

class SharedStoreReference extends SharedReference {
  final String id;

  SharedStoreReference(this.id);

  factory SharedStoreReference.fromJson(Map<String, dynamic> json) {
    return SharedStoreReference(json['id']);
  }

  @override
  Map<String, dynamic> toJson() => {'id': id};

  @override
  String toString() => 'SharedStoreReference${toJson()}';
}

class SharedMapReference extends SharedReference {
  final String id;
  final SharedStoreReference sharedStoreReference;

  SharedMapReference(this.id, this.sharedStoreReference);

  factory SharedMapReference.fromJson(Map<String, dynamic> json) {
    var sharedStoreReference =
        SharedStoreReference.fromJson(json['sharedStore']);
    return SharedMapReference(json['id'], sharedStoreReference);
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'sharedStore': sharedStoreReference.toJson(),
      };

  @override
  String toString() => 'SharedMapReference${toJson()}';
}
