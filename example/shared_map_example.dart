import 'dart:io' show exit;
import 'dart:isolate';

import 'package:shared_map/shared_map.dart';

void main() async {
  var store1 = SharedStore('t1');

  var m1 = await store1.getSharedMap<String, int>('m1');

  var va1 = await m1!.get('a'); // return `null`
  print('get> va1: $va1');

  var va2 = m1.put('a', 11); // put and return `11`
  print('put> va2: $va2');

  final sharedMapReference = m1.sharedReference();
  print('sharedMapReference: $sharedMapReference');

  // Use the `SharedMap` inside an `Isolate`:
  var va3 = await Isolate.run<int?>(() async {
    // Instantiate from `sharedMapReference`:
    var m2 = SharedMap<String, int>.fromSharedReference(sharedMapReference);
    var va3 = await m2.get('a'); // return `11`
    return va3;
  }); // Isolate returns 11

  print('Isolate return> va3: $va3');

  // Use the `SharedMap` inside another `Isolate`:
  var va4 = await Isolate.run<int?>(() async {
    // Instantiate from `sharedMapReference`:
    var m3 = SharedMap<String, int>.fromSharedReference(sharedMapReference);
    var va4 = await m3.put('a', 111); // put and return 111
    return va4;
  }); // Isolate returns 111

  print('Isolate return> va4: $va4');

  final sharedMapID = sharedMapReference.id;
  print('sharedMapID: $sharedMapID');

  final sharedStoreReference = store1.sharedReference();
  print('shareStoreReference: $sharedStoreReference');

  // Use the `SharedStore` inside another `Isolate`:
  var va5 = await Isolate.run<int?>(() async {
    // Instantiate from `shareStoreReference`:
    var store2 = SharedStore.fromSharedReference(sharedStoreReference);
    // Get the `SharedMap` through the `SharedStore`:
    var m4 = await store2.getSharedMap(sharedMapID);
    var va5 = await m4?.put('a', 222); // put and return `222`
    return va5;
  });

  print('Isolate return> va5: $va5'); // print `222`

  var va6 = await m1.get('a');
  print('get> va6: $va6'); // print `222`

  var va7 = await m1.get('a');
  print('get> va7: $va7'); // print `222`

  var va8 = await m1.putIfAbsent('a', 1001);
  print('putIfAbsent> va8: $va8'); // print `1001`

  var va9 = await Isolate.run<int?>(() async {
    var store4 = SharedStore.fromSharedReference(sharedStoreReference);
    var m6 = await store4.getSharedMap(sharedMapID);
    var va9 = await m6?.putIfAbsent('a', 1001);
    return va9;
  });

  print('Isolate return> va9: $va9'); // print `222`

  var vb1 = await m1.putIfAbsent('b', 2001);
  print('putIfAbsent> vb1: $vb1'); // print `2001`
  print('get> vb1: ${await m1.get('b')}'); // print `2001`

  var vc1 = await Isolate.run<int?>(() async {
    var store5 = SharedStore.fromSharedReference(sharedStoreReference);
    var m7 = await store5.getSharedMap(sharedMapID);
    var va11 = await m7?.putIfAbsent('c', 3001);
    return va11;
  });

  print('Isolate return> vc1: $vc1'); // print `3001`
  print('get> vc1: ${await m1.get('c')}'); // print `3001`

  exit(0);
}
