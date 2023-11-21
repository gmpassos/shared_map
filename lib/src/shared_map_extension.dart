import 'dart:async';

import 'shared_map_base.dart';
import 'shared_map_cached.dart';

/// Extension on [Future]<[SharedMap]`<K, V>`>
extension FutureSharedMapExtension<K, V> on Future<SharedMap<K, V>> {
  Future<V?> get(K key) => then((o) => o.get(key));

  Future<V?> put(K key, V? value) => then((o) => o.put(key, value));

  Future<V?> putIfAbsent(K key, V? absentValue) =>
      then((o) => o.putIfAbsent(key, absentValue));

  Future<V?> remove(K key) => then((o) => o.remove(key));

  Future<List<V?>> removeAll(List<K> keys) => then((o) => o.removeAll(keys));

  Future<List<K>> keys() => then((o) => o.keys());

  Future<List<V>> values() => then((o) => o.values());

  Future<List<MapEntry<K, V>>> entries() => then((o) => o.entries());

  Future<List<MapEntry<K, V>>> where(bool Function(K key, V value) test) =>
      then((o) => o.where(test));

  Future<int> length() => then((o) => o.length());

  Future<int> clear() => then((o) => o.clear());

  Future<SharedMapCached<K, V>> cached({Duration? timeout}) =>
      then((o) => o.cached(timeout: timeout));
}

/// Extension on [FutureOr]<[SharedMap]`<K, V>`>
extension FutureOrSharedMapExtension<K, V> on FutureOr<SharedMap<K, V>> {
  FutureOr<V?> get(K key) {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.get(key);
    } else {
      return self.get(key);
    }
  }

  FutureOr<V?> put(K key, V? value) {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.put(key, value);
    } else {
      return self.put(key, value);
    }
  }

  FutureOr<V?> putIfAbsent(K key, V? absentValue) {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.putIfAbsent(key, absentValue);
    } else {
      return self.putIfAbsent(key, absentValue);
    }
  }

  FutureOr<V?> remove(K key) {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.remove(key);
    } else {
      return self.remove(key);
    }
  }

  FutureOr<List<V?>> removeAll(List<K> keys) {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.removeAll(keys);
    } else {
      return self.removeAll(keys);
    }
  }

  FutureOr<List<K>> keys() {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.keys();
    } else {
      return self.keys();
    }
  }

  FutureOr<List<V>> values() {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.values();
    } else {
      return self.values();
    }
  }

  FutureOr<List<MapEntry<K, V>>> entries() {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.entries();
    } else {
      return self.entries();
    }
  }

  FutureOr<List<MapEntry<K, V>>> where(bool Function(K key, V value) test) {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.where(test);
    } else {
      return self.where(test);
    }
  }

  FutureOr<int> length() {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.length();
    } else {
      return self.length();
    }
  }

  FutureOr<int> clear() {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.clear();
    } else {
      return self.clear();
    }
  }

  FutureOr<SharedMapCached<K, V>> cached({Duration? timeout}) {
    var self = this;
    if (self is Future<SharedMap<K, V>>) {
      return self.cached(timeout: timeout);
    } else {
      return self.cached(timeout: timeout);
    }
  }
}

extension IterableMapEntryExtension<K, V> on Iterable<MapEntry<K, V>> {
  List<(K, V)> toRecords() => map((e) => (e.key, e.value)).toList();

  List<({K key, V value})> toRecordsNamed() =>
      map((e) => (key: e.key, value: e.value)).toList();
}

extension FutureIterableMapEntryExtension<K, V>
    on Future<Iterable<MapEntry<K, V>>> {
  Future<List<(K, V)>> toRecords() => then((o) => o.toRecords());

  Future<List<({K key, V value})>> toRecordsNamed() =>
      then((o) => o.toRecordsNamed());
}

extension FutureOrIterableMapEntryExtension<K, V>
    on FutureOr<Iterable<MapEntry<K, V>>> {
  FutureOr<List<(K, V)>> toRecords() {
    var self = this;
    if (self is Future<Iterable<MapEntry<K, V>>>) {
      return self.toRecords();
    } else {
      return self.toRecords();
    }
  }

  FutureOr<List<({K key, V value})>> toRecordsNamed() {
    var self = this;
    if (self is Future<Iterable<MapEntry<K, V>>>) {
      return self.toRecordsNamed();
    } else {
      return self.toRecordsNamed();
    }
  }
}
