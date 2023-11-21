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
