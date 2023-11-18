import 'dart:async';

import 'package:shared_map/src/shared_map_base.dart';

/// Cached version of a [SharedMap].
class SharedMapCached<K, V> implements SharedMap<K, V> {
  final SharedMap<K, V> _sharedMap;

  /// The default timeout of the cached entries.
  final Duration timeout;

  SharedMapCached(this._sharedMap,
      {Duration? timeout = const Duration(seconds: 1)})
      : timeout = const Duration(seconds: 1);

  @override
  SharedStore get sharedStore => _sharedMap.sharedStore;

  @override
  String get id => _sharedMap.id;

  final Map<K, (DateTime, V)> _cache = {};

  Map<K, V> get cachedEntries =>
      _cache.map((key, value) => MapEntry(key, value.$2));

  void clearCache() => _cache.clear();

  @override
  FutureOr<V?> get(K key, {Duration? timeout, bool refresh = false}) {
    var now = DateTime.now();

    if (refresh) {
      var val = _sharedMap.get(key);
      return _cacheValue(key, val, now);
    }

    timeout ??= this.timeout;

    var prev = _cache[key];
    if (prev != null) {
      var elapsedTime = now.difference(prev.$1);
      if (elapsedTime <= timeout) {
        return prev.$2;
      }
    }

    var val = _sharedMap.get(key);
    return _cacheValue(key, val, now);
  }

  FutureOr<V?> _cacheValue(K key, FutureOr<V?> value, DateTime now) {
    if (value is Future<V?>) {
      return value.then((value) {
        if (value != null) {
          _cache[key] = (now, value);
        }
        return value;
      });
    } else if (value != null) {
      _cache[key] = (now, value);
      return value;
    } else {
      return null;
    }
  }

  @override
  FutureOr<V?> put(K key, V? value) {
    var val = _sharedMap.put(key, value);
    return _cacheValue(key, val, DateTime.now());
  }

  @override
  FutureOr<V?> putIfAbsent(K key, V? absentValue) {
    var val = _sharedMap.putIfAbsent(key, absentValue);
    return _cacheValue(key, val, DateTime.now());
  }

  @override
  SharedMapReference sharedReference() => _sharedMap.sharedReference();

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => this;

  @override
  String toString() => 'SharedMapCached{timeout: $timeout}->$_sharedMap';
}
