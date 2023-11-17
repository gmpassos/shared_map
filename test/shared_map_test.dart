@TestOn('vm')
@Timeout(Duration(minutes: 20))
import 'dart:isolate';

import 'package:shared_map/shared_map.dart';
import 'package:test/test.dart';

void main() {
  group('SharedMap', () {
    test('basic', () async {
      var store1 = SharedStore('t1');

      var m1 = await store1.getSharedMap<String, int>('m1');
      expect(m1, isNotNull);

      var va1 = await m1!.get('a');
      expect(va1, isNull);

      var va2 = m1.put('a', 11);
      expect(va2, equals(11));

      final sharedMapReference = m1.shareReference();

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

      final shareStoreReference = store1.shareReference();

      var va5 = await Isolate.run<int?>(() async {
        var store2 = SharedStore.fromSharedReference(shareStoreReference);
        var m4 = await store2.getSharedMap(sharedMapReference.id);
        var va5 = await m4?.get('a');
        return va5;
      });

      expect(va5, equals(111));

      var va6 = await Isolate.run<int?>(() async {
        var store3 = SharedStore.fromSharedReference(shareStoreReference);
        var m5 = await store3.getSharedMap(sharedMapReference.id);
        var va6 = await m5?.put('a', 222);
        return va6;
      });

      expect(va6, equals(222));

      var va7 = await m1.get('a');
      expect(va7, equals(222));
    });
  });
}
