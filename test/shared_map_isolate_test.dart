@TestOn('vm')
@Timeout(Duration(minutes: 5))
import 'dart:isolate';

import 'package:shared_map/shared_map.dart';
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
        var vc1 = await m7?.putIfAbsent('c', 3001);
        return vc1;
      });

      expect(vc1, equals(3001));
      expect(await m1.get('c'), equals(3001));

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
    });
  });

  group('SharedStoreField', () {
    final sharedStoreID = 'SharedMap:test[field]';
    final sharedMapID = 'SharedMap:test[field]';

    final SharedStoreField sharedStoreField = SharedStoreField(sharedStoreID);

    test('basic', () async {
      final store1 = sharedStoreField.sharedStore;

      var m1 = await store1.getSharedMap(sharedMapID);

      var va1 = await m1!.get('a');
      expect(va1, isNull);

      var va2 = await m1.put('a', 11);
      expect(va2, equals(11));

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
        var va4 = await m3?.put('a', 111);
        return va4;
      });

      expect(va4, equals(111));
      expect(await m1.get('a'), equals(111));
    });
  });
}
