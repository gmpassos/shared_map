import 'dart:io';
import 'dart:isolate';

import 'package:shared_map/shared_map.dart';

void main() async {
  var store1 = SharedStore('t1');

  var m1 = await store1.getSharedMap<String, int>('m1');

  var va1 = await m1!.get('a'); // return `null`
  print('va1: $va1');

  var va2 = m1.put('a', 11); // put and return `11`
  print('va2: $va2');

  final sharedMapReference = m1.shareReference();
  print('sharedMapReference: $sharedMapReference');

  // Use the `SharedMap` inside an `Isolate`:
  var va3 = await Isolate.run<int?>(() async {
    // Instantiate from `sharedMapReference`:
    var m2 = SharedMap<String, int>.fromSharedReference(sharedMapReference);
    var va3 = await m2.get('a'); // return `11`
    return va3;
  }); // Isolate returns 11

  print('va3: $va3');

  // Use the `SharedMap` inside another `Isolate`:
  var va4 = await Isolate.run<int?>(() async {
    // Instantiate from `sharedMapReference`:
    var m3 = SharedMap<String, int>.fromSharedReference(sharedMapReference);
    var va4 = await m3.put('a', 111); // put and return 111
    return va4;
  }); // Isolate returns 111

  print('va4: $va4');

  final sharedMapID = sharedMapReference.id;
  print('sharedMapID: $sharedMapID');

  final shareStoreReference = store1.shareReference();
  print('shareStoreReference: $shareStoreReference');

  // Use the `SharedStore` inside an `Isolate`:
  var va5 = await Isolate.run<int?>(() async {
    // Instantiate from `shareStoreReference`:
    var store2 = SharedStore.fromSharedReference(shareStoreReference);
    // Get the `SharedMap` through the `SharedStore`:
    var m4 = await store2.getSharedMap(sharedMapID);
    var va5 = await m4?.put('a', 222); // put and return `222`
    return va5;
  });

  print('va5: $va5'); // print `222`

  var va6 = await m1.get('a');
  print('va6: $va6'); // print `222`

  exit(0);
}
