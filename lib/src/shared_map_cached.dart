import 'dart:async';

import 'package:shared_map/shared_map.dart';

import 'shared_map_base.dart';

/// Cached version of a [SharedMap].
class SharedMapCached<K, V> implements SharedMap<K, V> {
  final SharedMap<K, V> _sharedMap;

  /// The default timeout of the cached entries.
  final Duration timeout;

  /// The default cache timeout (1 sec).
  static const defaultTimeout = Duration(seconds: 1);

  SharedMapCached(this._sharedMap, {Duration? timeout = defaultTimeout})
      : timeout = timeout ??= defaultTimeout;

  @override
  SharedMapEntryCallback<K, V>? get onPut => _sharedMap.onPut;

  @override
  set onPut(SharedMapEntryCallback<K, V>? callback) =>
      _sharedMap.onPut = callback;

  @override
  SharedMapEntryCallback<K, V>? get onRemove => _sharedMap.onRemove;

  @override
  set onRemove(SharedMapEntryCallback<K, V>? callback) =>
      _sharedMap.onRemove = callback;

  @override
  void setCallbacks(
          {SharedMapEntryCallback<K, V>? onPut,
          SharedMapEntryCallback<K, V>? onRemove}) =>
      _sharedMap.setCallbacks(onPut: onPut, onRemove: onRemove);

  @override
  void setCallbacksDynamic<K1, V1>(
          {SharedMapEntryCallback<K1, V1>? onPut,
          SharedMapEntryCallback<K1, V1>? onRemove}) =>
      _sharedMap.setCallbacksDynamic(onPut: onPut, onRemove: onRemove);

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

    var getAsync = _getAsync;
    if (getAsync != null) {
      return getAsync;
    }

    var val = _sharedMap.get(key);
    return _cacheValue(key, val, now);
  }

  Future<V?>? _getAsync;

  FutureOr<V?> _cacheValue(K key, FutureOr<V?> value, DateTime now) {
    if (value is Future<V?>) {
      return _getAsync = value.then((value) {
        if (value != null) {
          _cache[key] = (now, value);
        }
        _getAsync = null;
        return value;
      }, onError: (e) {
        _getAsync = null;
        throw e;
      });
    } else {
      _getAsync = null;

      if (value != null) {
        _cache[key] = (now, value);
        return value;
      } else {
        return null;
      }
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
  FutureOr<V?> remove(K key) {
    _cache.remove(key);
    return _sharedMap.remove(key);
  }

  @override
  FutureOr<List<V?>> removeAll(List<K> keys) {
    for (var k in keys) {
      _cache.remove(k);
    }

    return _sharedMap.removeAll(keys);
  }

  (DateTime, List<K>)? _keysCached;

  @override
  FutureOr<List<K>> keys({Duration? timeout, bool refresh = false}) {
    var now = DateTime.now();

    if (refresh) {
      var keys = _sharedMap.keys();
      return _cacheKeys(keys, now);
    }

    var keysCached = _keysCached;
    if (keysCached != null) {
      timeout ??= this.timeout;

      var elapsedTime = now.difference(keysCached.$1);
      if (elapsedTime <= timeout) {
        return keysCached.$2;
      }
    }

    var keysAsync = _keysAsync;
    if (keysAsync != null) {
      return keysAsync;
    }

    var keys = _sharedMap.keys();
    return _cacheKeys(keys, now);
  }

  Future<List<K>>? _keysAsync;

  FutureOr<List<K>> _cacheKeys(FutureOr<List<K>> keys, DateTime now) {
    if (keys is Future<List<K>>) {
      return _keysAsync = keys.then((keys) {
        _keysCached = (now, keys);
        _keysAsync = null;
        return keys;
      }, onError: (e) {
        _keysAsync = null;
        throw e;
      });
    } else {
      _keysCached = (now, keys);
      _keysAsync = null;
      return keys;
    }
  }

  (DateTime, List<V>)? _valuesCached;

  @override
  FutureOr<List<V>> values({Duration? timeout, bool refresh = false}) {
    var now = DateTime.now();

    if (refresh) {
      var values = _sharedMap.values();
      return _cacheValues(values, now);
    }

    var valuesCached = _valuesCached;
    if (valuesCached != null) {
      timeout ??= this.timeout;

      var elapsedTime = now.difference(valuesCached.$1);
      if (elapsedTime <= timeout) {
        return valuesCached.$2;
      }
    }

    var valuesAsync = _valuesAsync;
    if (valuesAsync != null) {
      return valuesAsync;
    }

    var values = _sharedMap.values();
    return _cacheValues(values, now);
  }

  Future<List<V>>? _valuesAsync;

  FutureOr<List<V>> _cacheValues(FutureOr<List<V>> values, DateTime now) {
    if (values is Future<List<V>>) {
      return _valuesAsync = values.then((values) {
        _valuesCached = (now, values);
        _valuesAsync = null;
        return values;
      }, onError: (e) {
        _valuesAsync = null;
        throw e;
      });
    } else {
      _valuesCached = (now, values);
      _valuesAsync = null;
      return values;
    }
  }

  (DateTime, List<MapEntry<K, V>>)? _entriesCached;

  @override
  FutureOr<List<MapEntry<K, V>>> entries(
      {Duration? timeout, bool refresh = false}) {
    var now = DateTime.now();

    if (refresh) {
      var entries = _sharedMap.entries();
      return _cacheEntries(entries, now);
    }

    var entriesCached = _entriesCached;
    if (entriesCached != null) {
      timeout ??= this.timeout;

      var elapsedTime = now.difference(entriesCached.$1);
      if (elapsedTime <= timeout) {
        return entriesCached.$2;
      }
    }

    var entriesAsync = _entriesAsync;
    if (entriesAsync != null) {
      return entriesAsync;
    }

    var entries = _sharedMap.entries();
    return _cacheEntries(entries, now);
  }

  Future<List<MapEntry<K, V>>>? _entriesAsync;

  FutureOr<List<MapEntry<K, V>>> _cacheEntries(
      FutureOr<List<MapEntry<K, V>>> entries, DateTime now) {
    if (entries is Future<List<MapEntry<K, V>>>) {
      return _entriesAsync = entries.then((values) {
        _entriesCached = (now, values);
        _entriesAsync = null;
        return values;
      }, onError: (e) {
        _entriesAsync = null;
        throw e;
      });
    } else {
      _entriesCached = (now, entries);
      _entriesAsync = null;
      return entries;
    }
  }

  @override
  FutureOr<List<MapEntry<K, V>>> where(bool Function(K key, V value) test) =>
      _sharedMap.where(test);

  (DateTime, int)? _keysLengthCached;

  @override
  FutureOr<int> length({Duration? timeout, bool refresh = false}) {
    var now = DateTime.now();

    if (refresh) {
      var length = _sharedMap.length();
      return _cacheKeysLength(length, now);
    }

    var keysLengthCached = _keysLengthCached;
    if (keysLengthCached != null) {
      timeout ??= this.timeout;

      var elapsedTime = now.difference(keysLengthCached.$1);
      if (elapsedTime <= timeout) {
        return keysLengthCached.$2;
      }
    }

    var lengthAsync = _lengthAsync;
    if (lengthAsync != null) {
      return lengthAsync;
    }

    var length = _sharedMap.length();
    return _cacheKeysLength(length, now);
  }

  Future<int>? _lengthAsync;

  FutureOr<int> _cacheKeysLength(FutureOr<int> length, DateTime now) {
    if (length is Future<int>) {
      return _lengthAsync = length.then((length) {
        _keysLengthCached = (now, length);
        _lengthAsync = null;
        return length;
      }, onError: (e) {
        _lengthAsync = null;
        throw e;
      });
    } else {
      _keysLengthCached = (now, length);
      _lengthAsync = null;
      return length;
    }
  }

  @override
  FutureOr<int> clear() {
    _cache.clear();
    return _sharedMap.clear();
  }

  @override
  SharedMapReference sharedReference() => _sharedMap.sharedReference();

  @override
  SharedMapCached<K, V> cached({Duration? timeout}) => this;

  @override
  String toString() => 'SharedMapCached{timeout: $timeout}->$_sharedMap';
}
