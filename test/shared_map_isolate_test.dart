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

      var va6 = await Isolate.run<int?>(() async {
        var store3 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store3.getSharedMap(sharedMapID);
        var va6 = await m5?.put('a', 222);
        return va6;
      });

      expect(va6, equals(222));

      expect(await cached1.get('a'), equals(111));
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
      }
    });
  });
}