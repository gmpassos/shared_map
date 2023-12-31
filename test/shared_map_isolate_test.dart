@TestOn('vm')
@Timeout(Duration(minutes: 5))
import 'dart:isolate';

import 'package:shared_map/shared_map.dart';
import 'package:shared_map/src/shared_map_isolate.dart';
import 'package:test/test.dart';

void main() {
  group('SharedMap (Isolate)', () {
    test('basic', () async {
      var store1 = SharedStore('t1');

      var m1 = await store1.getSharedMap<String, int>('m1');
      expect(m1, isNotNull);

      var va1 = await m1!.get('a');
      expect(va1, isNull);

      var va2 = m1.put('a', 11);
      expect(va2, equals(11));

      final sharedMapReference = m1.sharedReference();

      var va3 = await Isolate.run<int?>(() async {
        var m2 = SharedMap<String, int>.fromSharedReference(sharedMapReference);

        var sharedReference2 = m2.sharedReference();
        if (sharedReference2.id != sharedMapReference.id) {
          throw StateError("Invalid `sharedReference`");
        }

        if (sharedMapReference is SharedMapReferenceIsolate &&
            sharedReference2 is SharedMapReferenceIsolate) {
          if (!identical(
              sharedMapReference.serverPort, sharedReference2.serverPort)) {
            throw StateError("Invalid `sharedReference.serverPort`");
          }
        }

        if (sharedReference2.sharedStoreReference.id !=
            sharedMapReference.sharedStoreReference.id) {
          throw StateError("Invalid `sharedReference.sharedStoreReference`");
        }

        var va3 = await m2.get('a');
        return va3;
      });

      expect(va3, equals(11));

      var va4 = await Isolate.run<int?>(() async {
        var m3 = SharedMap<String, int>.fromSharedReference(sharedMapReference);
        var va4 = await m3.put('a', 111);
        return va4;
      });

      expect(va4, equals(111));

      final sharedStoreReference = store1.sharedReference();
      final sharedMapID = sharedMapReference.id;

      var va5 = await Isolate.run<int?>(() async {
        var store2 = SharedStore.fromSharedReference(sharedStoreReference);
        var m4 = await store2.getSharedMap(sharedMapID);
        var va5 = await m4?.get('a');
        return va5;
      });

      expect(va5, equals(111));

      var cached1 = m1.cached();
      expect(await cached1.get('a'), equals(111));

      {
        var mainPort = ReceivePort();
        var sendPort = mainPort.sendPort;

        var vaAsync = Isolate.run<int?>(() async {
          var isolatePort = ReceivePort();

          var store3 = SharedStore.fromSharedReference(sharedStoreReference);
          var m5 = await store3.getSharedMap(sharedMapID);

          var va6 = await m5!.get('a');
          if (va6 != 111) throw StateError("expect: 111 ; got: $va6");

          var cached = m5.cached(timeout: Duration(seconds: 5));
          var vaCached1 = await cached.get('a');
          if (vaCached1 != 111) {
            throw StateError("expect: 111 ; got: $vaCached1");
          }

          sendPort.send(isolatePort.sendPort);
          bool resume = await isolatePort.first;
          assert(resume);

          va6 = await m5.get('a');
          if (va6 != 1111) throw StateError("expect: 1111 ; got: $va6");

          var vaCached2 = await cached.get('a');
          if (vaCached2 != 111) {
            throw StateError("expect: 111 ; got: $vaCached2");
          }

          var vaCached3 = await cached.get('a', refresh: true);
          if (vaCached3 != 1111) {
            throw StateError("expect: 1111 ; got: $vaCached2");
          }

          return va6;
        });

        SendPort isolateSendPort = await mainPort.first;

        m1.put('a', 1111);

        isolateSendPort.send(true);

        expect(await vaAsync, equals(1111));

        var va6 = await Isolate.run<int?>(() async {
          var store3 = SharedStore.fromSharedReference(sharedStoreReference);
          var m5 = await store3.getSharedMap(sharedMapID);
          var va6 = await m5?.put('a', 222);
          return va6;
        });

        expect(va6, equals(222));
      }

      expect(await cached1.get('a'), equals(222));
      expect(await cached1.get('a', refresh: true), equals(222));
      expect(await cached1.get('a'), equals(222));

      var va7 = await m1.get('a');
      expect(va7, equals(222));

      var va8 = await m1.putIfAbsent('a', 1001);
      expect(va8, equals(222));

      var va9 = await Isolate.run<int?>(() async {
        var store4 = SharedStore.fromSharedReference(sharedStoreReference);
        var m6 = await store4.getSharedMap(sharedMapID);
        var va9 = await m6?.putIfAbsent('a', 1001);
        return va9;
      });

      expect(va9, equals(222));

      var vb1 = await m1.putIfAbsent('b', 2001);
      expect(vb1, equals(2001));
      expect(await m1.get('b'), equals(2001));

      expect(await m1.keys(), equals(['a', 'b']));
      expect(await m1.length(), equals(2));

      var vc1 = await Isolate.run<int?>(() async {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m7 = await store5.getSharedMap(sharedMapID);

        var keys = await m7!.keys();
        if (!_listEquals(keys, ['a', 'b'])) {
          throw StateError("Expected: ['a', 'b'] ; got: $keys");
        }

        var values = await m7.values();
        if (!_listEquals(values, [222, 2001])) {
          throw StateError("Expected: [222, 2001] ; got: $values");
        }

        var entries = await m7.entries().toRecords();
        if (!_listEquals(entries, [('a', 222), ('b', 2001)])) {
          throw StateError("Expected: [222, 2001] ; got: $values");
        }

        var where = await m7.where((k, v) => v == 222).toRecords();
        if (!_listEquals(where, [('a', 222)])) {
          throw StateError("Expected: ['a', 222] ; got: $where");
        }

        var vc1 = await m7.putIfAbsent('c', 3001);
        return vc1;
      });

      expect(vc1, equals(3001));
      expect(await m1.get('c'), equals(3001));

      {
        var va = await Isolate.run<int?>(() async {
          var sharedStoreField = SharedStoreField.tryFrom(
            sharedStoreReference: sharedStoreReference,
          );

          if (sharedStoreField == null) {
            throw StateError("Null `sharedStoreField`");
          }

          var store5 = sharedStoreField.sharedStore;

          var m7 = await store5.getSharedMap(sharedMapID);

          var va = await m7!.get('a');
          if (va != 222) {
            throw StateError("Key `a`: expected 222 ; got: $va");
          }

          return va;
        });

        expect(va, equals(222));
      }

      {
        var va = await Isolate.run<int?>(() async {
          var sharedStoreField0 = SharedStoreField.from(
            sharedStoreReference: sharedStoreReference,
          );

          var sharedStoreField = SharedStoreField.tryFrom(
            sharedStore: sharedStoreField0.sharedStore,
          );

          if (sharedStoreField == null) {
            throw StateError("Null `sharedStoreField`");
          }

          var store5 = sharedStoreField.sharedStore;

          var m7 = await store5.getSharedMap(sharedMapID);

          var va = await m7!.get('a');
          if (va != 222) {
            throw StateError("Key `a`: expected 222 ; got: $va");
          }

          return va;
        });

        expect(va, equals(222));
      }

      {
        var cached2 = m1.cached();

        expect(identical(cached2, cached1), isTrue);
        expect(await cached2.get('a'), equals(222));

        expect(await cached2.putIfAbsent('a', 5555), equals(222));

        expect(await cached2.put('a', 333), equals(333));

        expect(await cached2.putIfAbsent('a', 6666), equals(333));
      }

      expect(await m1.get('a'), equals(333));

      expect(await m1.keys(), equals(['a', 'b', 'c']));
      expect(await m1.values(), equals([333, 2001, 3001]));
      expect(await m1.length(), equals(3));

      {
        var cached3 = m1.cached();

        expect(identical(cached3, cached1), isTrue);
        expect(await cached3.get('a'), equals(333));

        expect(await cached3.remove('a'), equals(333));

        expect(await cached3.get('a'), isNull);
      }

      expect(await m1.get('a'), isNull);

      expect(await m1.keys(), equals(['b', 'c']));
      expect(await m1.length(), equals(2));

      expect(await m1.removeAll(['b', 'x']), equals([2001, null]));

      expect(await m1.keys(), equals(['c']));
      expect(await m1.length(), equals(1));

      var cl1 = await Isolate.run<int>(() async {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m8 = await store5.getSharedMap(sharedMapID);
        return m8!.clear();
      });

      expect(cl1, equals(1));
      expect(await m1.length(), equals(0));

      expect(await m1.clear(), equals(0));
    });

    test('basic 1', () async {
      var store2 = SharedStore('t2');

      var events = <(String, String, int?)>[];

      expect(events, isEmpty);

      var m2 = await store2.getSharedMap<String, int>(
        'm2',
        onInitialize: (o) => events.add(('init', o.id, -1)),
        onAbsent: (k) {
          int? v;
          if (k == 'x') {
            v = -1111;
          } else if (k == 'y') {
            v = -2222;
          }
          events.add(('absent', k, v ?? 0));
          return v;
        },
        onPut: (k, v) => events.add(('put', k, v)),
        onRemove: (k, v) => events.add(('rm', k, v)),
      );
      expect(m2, isNotNull);

      final m2ID = m2!.id;

      expect(events, equals([('init', m2ID, -1)]));

      var va1 = await m2.get('a');
      expect(va1, isNull);

      expect(events, equals([('init', m2ID, -1), ('absent', 'a', 0)]));

      var va2 = await m2.put('a', 11);
      expect(va2, equals(11));

      expect(events,
          equals([('init', m2ID, -1), ('absent', 'a', 0), ('put', 'a', 11)]));

      final sharedStoreReference = store2.sharedReference();
      final sharedMapID = m2.id;

      var va3 = await Isolate.run<int?>(() async {
        var store3 = SharedStore.fromSharedReference(sharedStoreReference);
        var m3 = await store3.getSharedMap(sharedMapID);
        var va3 = await m3?.get('a');
        return va3;
      });

      expect(va3, equals(11));

      expect(events,
          equals([('init', m2ID, -1), ('absent', 'a', 0), ('put', 'a', 11)]));

      var va4 = await Isolate.run<int?>(() async {
        var store4 = SharedStore.fromSharedReference(sharedStoreReference);
        var m4 = await store4.getSharedMap(sharedMapID);
        var va4 = await m4?.put('a', 111);
        return va4;
      });

      expect(va4, equals(111));

      expect(
          events,
          equals([
            ('init', m2ID, -1),
            ('absent', 'a', 0),
            ('put', 'a', 11),
            ('put', 'a', 111)
          ]));

      var va5 = await Isolate.run<int?>(() async {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store5.getSharedMap(sharedMapID);
        var va5 = await m5?.cached().remove('a');
        return va5;
      });

      expect(va5, equals(111));

      expect(
          events,
          equals([
            ('init', m2ID, -1),
            ('absent', 'a', 0),
            ('put', 'a', 11),
            ('put', 'a', 111),
            ('rm', 'a', 111)
          ]));

      var va6 = await Isolate.run<int?>(() async {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store5.getSharedMap(sharedMapID);
        var va6 = await m5?.cached().remove('x');
        return va6;
      });

      expect(va6, equals(-1111));

      expect(
          events,
          equals([
            ('init', m2ID, -1),
            ('absent', 'a', 0),
            ('put', 'a', 11),
            ('put', 'a', 111),
            ('rm', 'a', 111),
            ('absent', 'x', -1111),
            ('rm', 'x', -1111),
          ]));

      var va7 = await Isolate.run<int?>(() async {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store5.getSharedMap(sharedMapID);
        var va7 = await m5?.cached().get('y');
        return va7;
      });

      expect(va7, equals(-2222));

      expect(
          events,
          equals([
            ('init', m2ID, -1),
            ('absent', 'a', 0),
            ('put', 'a', 11),
            ('put', 'a', 111),
            ('rm', 'a', 111),
            ('absent', 'x', -1111),
            ('rm', 'x', -1111),
            ('absent', 'y', -2222),
          ]));

      expect(await m2.get('y'), equals(-2222));

      expect(
          events,
          equals([
            ('init', m2ID, -1),
            ('absent', 'a', 0),
            ('put', 'a', 11),
            ('put', 'a', 111),
            ('rm', 'a', 111),
            ('absent', 'x', -1111),
            ('rm', 'x', -1111),
            ('absent', 'y', -2222),
          ]));

      var l8 = await Isolate.run<List?>(() async {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store5.getSharedMap(sharedMapID);
        var l8 = await m5?.cached().removeAll(['a', 'y']);
        return l8;
      });

      expect(l8, equals([null, -2222]));
    });

    test('basic 2', () async {
      var store2 = SharedStore('t3');

      final sharedStoreReference = store2.sharedReference();
      final sharedMapID = 'm2';

      var events = <(String, String, Object?)>[];

      expect(events, isEmpty);

      var va0 = await Isolate.run<int?>(() async {
        var events2 = <(String, String, Object?)>[];

        var store3 = SharedStore.fromSharedReference(sharedStoreReference);
        var m3 = await store3.getSharedMap<String, int>(sharedMapID,
            onInitialize: (o) {
          var aux = o.isAuxiliaryInstance ? 'aux' : 'main';
          events2.add(('init', o.id, aux));
        });

        if (events2.length != 1 || events2[0] != ('init', sharedMapID, 'aux')) {
          throw StateError("Invalid `events2` state: $events2");
        }

        if (!m3.isAuxiliaryInstance) {
          throw StateError("Invalid `isAuxiliaryInstance`: $m3");
        }
        if (m3.isMainInstance) {
          throw StateError("Invalid `isMainInstance`: $m3");
        }
        if (!m3.isSharedObject) {
          throw StateError("Invalid `isSharedObject`: $m3");
        }
        if (m3.asSharedObject == null) {
          throw StateError("Invalid `asSharedObject`: $m3");
        }

        var va0 = await m3?.get('a');
        return va0;
      });

      expect(va0, isNull);

      var m2 = await store2.getSharedMap<String, int>(sharedMapID,
          onInitialize: (o) {
        var aux = o.isAuxiliaryInstance ? 'aux' : 'main';
        events.add(('init', o.id, aux));
      });

      expect(m2, isNotNull);

      expect(m2?.isAuxiliaryInstance, isFalse);
      expect(m2?.isMainInstance, isTrue);
      expect(m2?.isSharedObject, isTrue);
      expect(m2?.asSharedObject, isNotNull);

      m2!.onPut = (k, v) => events.add(('put', k, v));
      m2.onRemove = (k, v) => events.add(('rm', k, v));

      expect(events, equals([('init', sharedMapID, 'main')]));

      var va1 = await m2.get('a');
      expect(va1, isNull);

      var va2 = await m2.put('a', 11);
      expect(va2, equals(11));

      expect(events, equals([('init', sharedMapID, 'main'), ('put', 'a', 11)]));

      var va3 = await Isolate.run<int?>(() async {
        var store3 = SharedStore.fromSharedReference(sharedStoreReference);
        var m3 = await store3.getSharedMap(sharedMapID);
        var va3 = await m3?.get('a');
        return va3;
      });

      expect(va3, equals(11));

      expect(events, equals([('init', sharedMapID, 'main'), ('put', 'a', 11)]));

      var va4 = await Isolate.run<int?>(() async {
        var store4 = SharedStore.fromSharedReference(sharedStoreReference);
        var m4 = await store4.getSharedMap(sharedMapID);
        var va4 = await m4?.put('a', 111);
        return va4;
      });

      expect(va4, equals(111));

      expect(
          events,
          equals([
            ('init', sharedMapID, 'main'),
            ('put', 'a', 11),
            ('put', 'a', 111)
          ]));

      var cached1 = m2.cached();

      var ca1 = cached1.get('a');
      var ca2 = cached1.get('a');

      expect(await ca1, equals(111));
      expect(await ca2, equals(111));

      var va5 = await Isolate.run<int?>(() async {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store5.getSharedMap(sharedMapID);

        var cached2 = m5!.cached();

        var ca1 = cached2.get('a');
        var ca2 = cached2.get('a');

        if (await ca1 != 111) throw StateError("Expect: 111 ; got: $ca1");
        if (await ca2 != 111) throw StateError("Expect: 111 ; got: $ca2");

        var va5 = await m5.remove('a');
        return va5;
      });

      expect(va5, equals(111));

      expect(
          events,
          equals([
            ('init', sharedMapID, 'main'),
            ('put', 'a', 11),
            ('put', 'a', 111),
            ('rm', 'a', 111)
          ]));

      var up0 = await m2.put('c', 1000);

      expect(up0, equals(1000));

      var up1Async = Isolate.run<int?>(() async {
        up(String k, int? v) => (v ?? 0) + 1;

        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store5.getSharedMap<String, int>(sharedMapID);

        var up0 = await m5!.get('c');
        if (up0 != 1000) throw StateError("Expect: 111 ; got: $up0");

        // Ensure that the other parallel update `Isolate`
        // has time to get the initial value.
        await Future.delayed(Duration(milliseconds: 100));

        var lastVal = 1000;
        for (var i = 0; i < 1100; ++i) {
          var val = await m5.update('c', up);
          if (val! <= lastVal) {
            throw StateError("Expect > $lastVal ; got: $val");
          }
          lastVal = val;
        }

        return lastVal;
      });

      var up2Async = Isolate.run<int?>(() async {
        up(String k, int? v) => (v ?? 0) + 1;

        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store5.getSharedMap<String, int>(sharedMapID);

        var up0 = await m5!.get('c');
        if (up0 != 1000) throw StateError("Expect: 111 ; got: $up0");

        // Ensure that the other parallel update `Isolate`
        // has time to get the initial value.
        await Future.delayed(Duration(milliseconds: 100));

        var lastVal = 1000;
        for (var i = 0; i < 1300; ++i) {
          var val = await m5.update('c', up);
          if (val! <= lastVal) {
            throw StateError("Expect > $lastVal ; got: $val");
          }
          lastVal = val;
        }

        return lastVal;
      });

      var up1 = await up1Async;
      var up2 = await up2Async;

      expect(up1, greaterThan(1000));
      expect(up2, greaterThan(1000));

      var up3 = await m2.get('c');

      expect(up3, equals(1000 + 1100 + 1300));

      var up4 = await m2.update('c', (k, v) => (v ?? 0) + 101);

      expect(up4, equals(1000 + 1100 + 1300 + 101));
    });
  });

  group('SharedStoreField', () {
    final sharedStoreID = 'SharedMap:test[field]';
    final sharedMapID = 'SharedMap:test[field]';

    final SharedStoreField sharedStoreField = SharedStoreField(sharedStoreID);

    test('basic', () async {
      final store1 = sharedStoreField.sharedStore;

      final events = <(String, String, int?)>[];

      var m1 = await store1.getSharedMap<String, int>(
        sharedMapID,
        onPut: (k, v) => events.add(('put', k, v)),
        onRemove: (k, v) => events.add(('rm', k, v)),
      );

      var va1 = await m1!.get('a');
      expect(va1, isNull);

      expect(events, isEmpty);

      var va2 = await m1.put('a', 11);
      expect(va2, equals(11));

      expect(events, [('put', 'a', 11)]);

      var va3 = await Isolate.run<int?>(() async {
        final store2 = sharedStoreField.sharedStore;
        var m2 = await store2.getSharedMap(sharedMapID);
        var va3 = await m2?.putIfAbsent('a', 1001);
        return va3;
      });

      expect(va3, equals(11));

      var va4 = await Isolate.run<int?>(() async {
        final store3 = sharedStoreField.sharedStore;
        var m3 = await store3.getSharedMap(sharedMapID);
        var va4 = await m3?.cached().put('a', 111);
        return va4;
      });

      expect(va4, equals(111));
      expect(await m1.get('a'), equals(111));

      var sharedMapField = SharedMapField.fromSharedMap(m1);

      {
        var sharedMapField2 = SharedMapField(m1.id, sharedStore: store1);
        expect(identical(sharedMapField2.sharedMap, m1), isTrue);
      }

      {
        expect(sharedMapField.sharedMap.id, equals(m1.id));

        var m2 = sharedMapField.sharedMap;
        expect(m2.id, equals(m1.id));

        expect(identical(m2, m1), isTrue);
      }

      var va5 = await Isolate.run<int?>(() async {
        var m3 = sharedMapField.sharedMap;

        var cached = sharedMapField.sharedMapCached();

        var va5 = await m3.get('a');
        if (va5 != 111) throw StateError("Expected: 111 ; got: $va5");

        var vaCached5 = await cached.get('a');
        if (vaCached5 != 111) throw StateError("Expected: 111 ; got: $va5");

        va5 = await m3.put('a', 11111);
        if (va5 != 11111) throw StateError("Expected: 11111 ; got: $va5");

        vaCached5 = await cached.get('a');
        if (vaCached5 != 111) throw StateError("Expected: 111 ; got: $va5");

        return va5;
      });

      expect(
          events, [('put', 'a', 11), ('put', 'a', 111), ('put', 'a', 11111)]);

      expect(va5, equals(11111));
      expect(await m1.get('a'), equals(11111));

      expect(await m1.clear(), equals(1));
      expect(await m1.length(), equals(0));

      expect(events, [
        ('put', 'a', 11),
        ('put', 'a', 111),
        ('put', 'a', 11111),
        ('rm', 'a', 11111)
      ]);
    });
  });
}

bool _listEquals<T>(List<T> l1, List<T> l2) {
  if (l1.length != l2.length) return false;

  for (var i = 0; i < l1.length; ++i) {
    var e1 = l1[i];
    var e2 = l2[i];
    if (e1 != e2) return false;
  }

  return true;
}
