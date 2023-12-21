import 'dart:async';

import 'package:shared_map/shared_map.dart';
import 'package:shared_map/src/not_shared_map.dart';
import 'package:shared_map/src/shared_map_generic.dart';
import 'package:shared_map/src/shared_object_field.dart';
import 'package:test/test.dart';

void main() {
  _doTest<String, int, SharedMapGeneric<String, int>>(
      'generic', (id) => SharedStoreGeneric(id));

  _doTest('not-shared', (id) => SharedStore.notShared());
}

void _doTest<K, V, T extends SharedMap<K, V>>(
    String testName, SharedStore Function(String id) storeInstantiator) {
  group('SharedMap ($testName)', () {
    test('basic', () async {
      var store1 = storeInstantiator('t1');

      var m1 = await store1.getSharedMap<String, int>('m1');
      expect(m1, isNotNull);
      expect(m1, isA<SharedMap<String, int>>());
      expect(m1, isA<T>());

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

        expect(va5, m4 is NotSharedMap ? isNull : equals(111));
      }

      {
        var store3 = SharedStore.fromSharedReference(sharedStoreReference);
        var m5 = await store3.getSharedMap(sharedMapID);
        var va6 = await m5?.put('a', 222);
        expect(va6, equals(222));
      }

      var va7 = await m1.get('a');

      expect(va7, equals(m1 is NotSharedMap ? 111 : 222));

      var va8 = await m1.putIfAbsent('a', 1001);

      expect(va8, equals(m1 is NotSharedMap ? 111 : 222));

      var cached1 = m1.cached();

      if (m1 is NotSharedMap) {
        expect(await cached1.get('a'), equals(111));
      } else {
        expect(await cached1.get('a'), equals(222));
      }

      {
        var store4 = SharedStore.fromSharedReference(sharedStoreReference);
        var m6 = await store4.getSharedMap(sharedMapID);
        var va9 = await m6?.putIfAbsent('a', 1001);
        expect(va9, equals(m6 is NotSharedMap ? 1001 : 222));
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
        expect(await m1.get('c'), m1 is NotSharedMap ? isNull : equals(3001));
      }

      {
        var storeField1 = SharedStoreField.fromSharedStore(m1.sharedStore);

        if (storeField1 is NotSharedStoreField) {
          expect(storeField1.sharedStoreID, isNot(equals(store1.id)));
        } else {
          expect(storeField1.sharedStoreID, equals(store1.id));
        }

        var store2 = storeField1.sharedStore;

        var sharedMapField =
            SharedMapField<K, V>.from(sharedMapReference: m1.sharedReference());

        if (storeField1 is NotSharedStoreField) {
          expect(sharedMapField, isA<NotSharedMapField<K, V>>());
        } else {
          expect(sharedMapField, isA<SharedMapField<K, V>>());
        }

        var m2 = await store2.getSharedMap<String, int>('m1');
        var m3 = sharedMapField.sharedMap;

        expect(m2.runtimeType, equals(m3.runtimeType));

        if (storeField1 is NotSharedStoreField) {
          expect(m2, isA<NotSharedMap<String, int>>());

          expect(await m2!.get('a'), isNull);
          expect(await m2.keys(), equals([]));

          expect(() => storeField1.instanceHandler,
              throwsA(isA<UnsupportedError>()));

          expect(() => sharedMapField.instanceHandler,
              throwsA(isA<UnsupportedError>()));
        } else {
          expect(m2, isA<SharedMap<String, int>>());

          expect(await m2!.get('a'), equals(222));
          expect(await m2.keys(), equals(['a', 'b', 'c']));

          expect(
              storeField1.instanceHandler,
              isA<
                  SharedFieldInstanceHandler<SharedStoreReference, SharedStore,
                      SharedStoreField>>());

          expect(
              sharedMapField.instanceHandler,
              isA<
                  SharedFieldInstanceHandler<SharedMapReference,
                      SharedMap<String, int>, SharedMapField<String, int>>>());
        }
      }

      var up1 = await m1.update('x', (k, v) => (v ?? 100) + 11);
      expect(up1, equals(111));

      var up2 = await m1.update('x', (k, v) => (v ?? 100) + 1);
      expect(up2, equals(112));

      var up3 = await m1.update('x', (k, v) => (v ?? 100) + 1);
      expect(up3, equals(113));

      // Finish NotSharedMap test:
      if (m1 is NotSharedMap) {
        {
          var cached2 = await _asFuture(m1).cached();

          expect(identical(cached2, cached1), isTrue);
          expect(await cached2.get('a'), equals(111));

          expect(await _asFuture(cached2).get('a'), equals(111));
          expect(await _asFutureOr(cached2).get('a'), equals(111));

          expect(await cached2.putIfAbsent('a', 5555), equals(111));

          expect(await _asFuture(cached2).putIfAbsent('a', 5555), equals(111));
          expect(
              await _asFutureOr(cached2).putIfAbsent('a', 5555), equals(111));

          expect(await cached2.put('a', 331), equals(331));
          expect(await cached2.get('a'), equals(331));

          expect(await _asFuture(cached2).put('a', 332), equals(332));
          expect(await cached2.get('a'), equals(332));

          expect(await _asFutureOr(cached2).put('a', 333), equals(333));

          expect(await cached2.putIfAbsent('a', 6666), equals(333));
        }
        return;
      }

      {
        var cached2 = await _asFuture(m1).cached();

        expect(identical(cached2, cached1), isTrue);
        expect(await cached2.get('a'), equals(222));

        expect(await _asFuture(cached2).get('a'), equals(222));
        expect(await _asFutureOr(cached2).get('a'), equals(222));

        expect(await cached2.putIfAbsent('a', 5555), equals(222));

        expect(await _asFuture(cached2).putIfAbsent('a', 5555), equals(222));
        expect(await _asFutureOr(cached2).putIfAbsent('a', 5555), equals(222));

        expect(await cached2.put('a', 331), equals(331));
        expect(await cached2.get('a'), equals(331));

        expect(await _asFuture(cached2).put('a', 332), equals(332));
        expect(await cached2.get('a'), equals(332));

        expect(await _asFutureOr(cached2).put('a', 333), equals(333));

        expect(await cached2.putIfAbsent('a', 6666), equals(333));
      }

      expect(await m1.get('a'), equals(333));

      expect(await _asFuture(m1).get('a'), equals(333));
      expect(await _asFutureOr(m1).get('a'), equals(333));

      expect(await m1.keys(), equals(['a', 'b', 'c', 'x']));
      expect(await m1.length(), equals(4));

      expect(await _asFuture(m1).keys(), equals(['a', 'b', 'c', 'x']));
      expect(await _asFuture(m1).values(), equals([333, 2001, 3001, 113]));
      expect((await _asFuture(m1).entries()).map((e) => (e.key, e.value)),
          equals([('a', 333), ('b', 2001), ('c', 3001), ('x', 113)]));
      expect(await _asFuture(m1).length(), equals(4));

      expect(await _asFutureOr(m1).keys(), equals(['a', 'b', 'c', 'x']));
      expect(await _asFutureOr(m1).values(), equals([333, 2001, 3001, 113]));
      expect(await _asFutureOr(m1).entries().toRecords(),
          equals([('a', 333), ('b', 2001), ('c', 3001), ('x', 113)]));

      expect(await _asFutureOr(m1).length(), equals(4));

      expect(await _asFutureOr(m1).where((k, v) => v == 333).toRecords(),
          equals([('a', 333)]));

      {
        var cached3 = await _asFutureOr(m1).cached();

        expect(identical(cached3, cached1), isTrue);
        expect(await cached3.get('a'), equals(333));

        expect(await cached3.remove('a'), equals(333));

        expect(await _asFuture(cached3).remove('a'), isNull);
        expect(await _asFutureOr(cached3).remove('a'), isNull);

        expect(await cached3.get('a'), isNull);
      }

      expect(await m1.get('a'), isNull);

      expect(await m1.keys(), equals(['b', 'c', 'x']));
      expect(await m1.length(), equals(3));

      expect(await m1.removeAll(['b', 'z']), equals([2001, null]));
      expect(await _asFuture(m1).removeAll(['b', 'z']), equals([null, null]));
      expect(await _asFutureOr(m1).removeAll(['b', 'z']), equals([null, null]));

      expect(await m1.keys(), equals(['c', 'x']));
      expect(await _asFuture(m1).length(), equals(2));

      expect(await _asFuture(m1).clear(), equals(2));
      expect(await m1.length(), equals(0));

      expect(await _asFutureOr(m1).clear(), equals(0));
    });

    test('onSharedMapPut + onSharedMapRemove', () async {
      var store2 = storeInstantiator('t2');

      if (store2 is! NotSharedStore) {
        expect(store2.id, equals('t2'));
      }

      var events = <(String, String, int?)>[];

      expect(events, isEmpty);

      var m2 = await store2.getSharedMap<String, int>(
        'm2',
        onInitialize: (o) => events.add(('init', o.id, -1)),
        onPut: (k, v) => events.add(('put', k, v)),
        onRemove: (k, v) => events.add(('rm', k, v)),
      );

      expect(m2, isNotNull);

      expect(m2.isAuxiliaryInstance, isFalse);
      expect(m2.isMainInstance, isFalse);
      expect(m2.isSharedObject, isFalse);
      expect(m2.asSharedObject, isNull);

      if (m2 is! NotSharedMap) {
        expect(m2?.id, equals('m2'));
      }

      final m2ID = m2!.id;

      expect(events, equals([('init', m2ID, -1)]));

      var va1 = await m2.get('a');
      expect(va1, isNull);

      expect(events, equals([('init', m2ID, -1)]));

      var va2 = m2.put('a', 11);
      expect(va2, equals(11));

      expect(events, equals([('init', m2ID, -1), ('put', 'a', 11)]));

      var va3 = m2.putIfAbsent('a', 111);
      expect(va3, equals(11));

      expect(events, equals([('init', m2ID, -1), ('put', 'a', 11)]));

      var va4 = m2.put('a', 111);
      expect(va4, equals(111));

      expect(events,
          equals([('init', m2ID, -1), ('put', 'a', 11), ('put', 'a', 111)]));

      expect(m2.remove("a"), equals(111));

      expect(
          events,
          equals([
            ('init', m2ID, -1),
            ('put', 'a', 11),
            ('put', 'a', 111),
            ('rm', 'a', 111)
          ]));
    });

    test('newUUID', () async {
      var store1 = storeInstantiator(ReferenceableType.newUUID());

      if (store1 is! NotSharedStore) {
        expect(store1.id, startsWith('UUID-'));
      }

      var m1 =
          await store1.getSharedMap<String, int>(ReferenceableType.newUUID());
      expect(m1, isNotNull);
      expect(m1, isA<SharedMap<String, int>>());
      expect(m1, isA<T>());

      if (m1 is! NotSharedMap) {
        expect(m1!.id, startsWith('UUID-'));
      }

      var va1 = await m1!.get('a');
      expect(va1, isNull);

      var va2 = m1.put('a', 11);
      expect(va2, equals(11));
    });
  });
}

FutureOr<T> _asFuture<T>(T o) => Future<T>.value(o);

FutureOr<T> _asFutureOr<T>(T o) => o;
