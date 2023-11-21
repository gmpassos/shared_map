import 'dart:async';

import 'package:shared_map/shared_map.dart';
import 'package:shared_map/src/shared_map_generic.dart';
import 'package:test/test.dart';

void main() {
  group('SharedMap (generic)', () {
    test('basic', () async {
      var store1 = SharedStoreGeneric('t1');

      var m1 = await store1.getSharedMap<String, int>('m1');
      expect(m1, isNotNull);
      expect(m1, isA<SharedMapGeneric<String, int>>());

      var va1 = await m1!.get('a');
      expect(va1, isNull);

      var va2 = m1.put('a', 11);
      expect(va2, equals(11));

      final sharedMapReference = m1.sharedReference();

      {
        var m2 = SharedMap<String, int>.fromSharedReference(sharedMapReference);
        var va3 = await m2.get('a');
        expect(va3, equals(11));
      }

      {
        var m3 = SharedMap<String, int>.fromSharedReference(sharedMapReference);
        var va4 = await m3.put('a', 111);
        expect(va4, equals(111));
      }

      final sharedStoreReference = store1.sharedReference();
      final sharedMapID = sharedMapReference.id;

      {
        var store2 = SharedStore.fromSharedReference(sharedStoreReference);
        var m4 = await store2.getSharedMap(sharedMapID);
        var va5 = await m4?.get('a');
        expect(va5, equals(111));
      }

      {
        var store3 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store3.getSharedMap(sharedMapID);
        var va6 = await m5?.put('a', 222);
        expect(va6, equals(222));
      }

      var va7 = await m1.get('a');
      expect(va7, equals(222));

      var va8 = await m1.putIfAbsent('a', 1001);
      expect(va8, equals(222));

      var cached1 = m1.cached();
      expect(await cached1.get('a'), equals(222));

      {
        var store4 = SharedStore.fromSharedReference(sharedStoreReference);
        var m6 = await store4.getSharedMap(sharedMapID);
        var va9 = await m6?.putIfAbsent('a', 1001);
        expect(va9, equals(222));
      }

      var vb1 = await m1.putIfAbsent('b', 2001);
      expect(vb1, equals(2001));
      expect(await m1.get('b'), equals(2001));

      expect(await m1.keys(), equals(['a', 'b']));
      expect(await m1.length(), equals(2));

      {
        var store5 = SharedStore.fromSharedReference(sharedStoreReference);
        var m7 = await store5.getSharedMap(sharedMapID);
        var vc1 = await m7?.putIfAbsent('c', 3001);

        expect(vc1, equals(3001));
        expect(await m1.get('c'), equals(3001));
      }

      {
        var cached2 = m1.cached();

        expect(identical(cached2, cached1), isTrue);
        expect(await cached2.get('a'), equals(222));

        expect(await Future.value(cached2).get('a'), equals(222));
        expect(await _asFutureOr(cached2).get('a'), equals(222));

        expect(await cached2.putIfAbsent('a', 5555), equals(222));

        expect(await Future.value(cached2).putIfAbsent('a', 5555), equals(222));
        expect(await _asFutureOr(cached2).putIfAbsent('a', 5555), equals(222));

        expect(await cached2.put('a', 331), equals(331));
        expect(await cached2.get('a'), equals(331));

        expect(await Future.value(cached2).put('a', 332), equals(332));
        expect(await cached2.get('a'), equals(332));

        expect(await _asFutureOr(cached2).put('a', 333), equals(333));

        expect(await cached2.putIfAbsent('a', 6666), equals(333));
      }

      expect(await m1.get('a'), equals(333));

      expect(await Future.value(m1).get('a'), equals(333));
      expect(await _asFutureOr(m1).get('a'), equals(333));

      expect(await m1.keys(), equals(['a', 'b', 'c']));
      expect(await m1.length(), equals(3));

      expect(await Future.value(m1).keys(), equals(['a', 'b', 'c']));
      expect(await Future.value(m1).length(), equals(3));

      expect(await _asFutureOr(m1).keys(), equals(['a', 'b', 'c']));
      expect(await _asFutureOr(m1).length(), equals(3));

      {
        var cached3 = m1.cached();

        expect(identical(cached3, cached1), isTrue);
        expect(await cached3.get('a'), equals(333));

        expect(await cached3.remove('a'), equals(333));

        expect(await Future.value(cached3).remove('a'), isNull);
        expect(await _asFutureOr(cached3).remove('a'), isNull);

        expect(await cached3.get('a'), isNull);
      }

      expect(await m1.get('a'), isNull);

      expect(await m1.keys(), equals(['b', 'c']));
      expect(await m1.length(), equals(2));

      expect(await m1.removeAll(['b', 'x']), equals([2001, null]));
      expect(
          await Future.value(m1).removeAll(['b', 'x']), equals([null, null]));
      expect(await _asFutureOr(m1).removeAll(['b', 'x']), equals([null, null]));

      expect(await m1.keys(), equals(['c']));
      expect(await m1.length(), equals(1));

      expect(await Future.value(m1).clear(), equals(1));
      expect(await m1.length(), equals(0));

      expect(await _asFutureOr(m1).clear(), equals(0));
    });

    test('newUUID', () async {
      var store1 = SharedStoreGeneric(SharedType.newUUID());

      expect(store1.id, startsWith('UUID-'));

      var m1 = await store1.getSharedMap<String, int>(SharedType.newUUID());
      expect(m1, isNotNull);
      expect(m1, isA<SharedMapGeneric<String, int>>());
      expect(m1!.id, startsWith('UUID-'));

      var va1 = await m1.get('a');
      expect(va1, isNull);

      var va2 = m1.put('a', 11);
      expect(va2, equals(11));
    });
  });
}

FutureOr<T> _asFutureOr<T>(T o) => o;
