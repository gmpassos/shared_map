# shared_map

[![pub package](https://img.shields.io/pub/v/shared_map.svg?logo=dart&logoColor=00b9fc)](https://pub.dartlang.org/packages/shared_map)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Codecov](https://img.shields.io/codecov/c/github/gmpassos/shared_map)](https://app.codecov.io/gh/gmpassos/shared_map)
[![Dart CI](https://github.com/gmpassos/shared_map/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/gmpassos/shared_map/actions/workflows/dart.yml)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/shared_map?logo=git&logoColor=white)](https://github.com/gmpassos/shared_map/releases)
[![New Commits](https://img.shields.io/github/commits-since/gmpassos/shared_map/latest?logo=git&logoColor=white)](https://github.com/gmpassos/shared_map/network)
[![Last Commits](https://img.shields.io/github/last-commit/gmpassos/shared_map?logo=git&logoColor=white)](https://github.com/gmpassos/shared_map/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/gmpassos/shared_map?logo=github&logoColor=white)](https://github.com/gmpassos/shared_map/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/gmpassos/shared_map?logo=github&logoColor=white)](https://github.com/gmpassos/shared_map)
[![License](https://img.shields.io/github/license/gmpassos/shared_map?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/shared_map/blob/master/LICENSE)

The package `shared_map` provides a versatile and synchronized `Map` data structure for Dart applications. This package is
designed to facilitate efficient sharing and communication of synchronized key-value pairs between different parts of your Dart
application, including `Isolate`s or external applications.

## Motivation

Modern Dart applications often involve complex architectures with multiple `Isolate`s or concurrent execution
environments. In such scenarios, efficient communication and synchronization of shared data become fundamental.
The `shared_map` package was created with the following motivations:

1. **Simplified Sharing:**
   Sharing data across different parts of an application, especially `Isolate`s, is often complex. The `shared_map`
   package simplifies this process by offering a shared and synchronized map structure.

2. **Concurrency-Friendly:**
   Managing concurrent execution requires careful consideration of data access and modification. The `shared_map`
   package is crafted to be concurrency-friendly, ensuring safe access and updates to shared data across multiple
   execution contexts.

3. **Scalability:**
   As applications grow and incorporate more concurrent patterns, having a dependable and scalable mechanism for sharing
   state becomes essential, especially across `Isolate`s. The `shared_map` package plays a role in enhancing the scalability of Dart applications by
   providing an efficient tool for data sharing.

## Usage

To use a `SharedMap`, first, create a `SharedStore`, then call `getSharedMap`.
To pass it to another `Isolate`, use its `SharedReference` returned by `SharedMap.shareReference()`,
then instantiate it with `SharedMap.fromSharedReference(sharedMapReference)`.

Example:
```dart
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
      var vc1 = await m7?.putIfAbsent('c', 3001);
      return vc1;
   });

   print('Isolate return> vc1: $vc1'); // print `3001`
   print('get> vc1: ${await m1.get('c')}'); // print `3001`

   exit(0);
}
```

Output:
```text
get> va1: null
put> va2: 11
sharedMapReference: SharedMapReference{id: m1, sharedStore: {id: t1}}
Isolate return> va3: 11
Isolate return> va4: 111
sharedMapID: m1
shareStoreReference: SharedStoreReference{id: t1}
Isolate return> va5: 222
get> va6: 222
get> va7: 222
putIfAbsent> va8: 222
Isolate return> va9: 222
putIfAbsent> vb1: 2001
get> vb1: 2001
Isolate return> vc1: 3001
get> vc1: 3001
```

## How it Works

When operating on a Dart platform with `Isolate`s, the mechanism involves a "server" version of a `SharedStore`
or `SharedMap` residing in the main `Isolate` responsible for storing data. Simultaneously, auxiliary Isolates host a
"client" version of these shared instances.

In the auxiliary Isolates, every `get` or `put` action on the `SharedMap` triggers an
Isolate message to the "server" version, fetching the current value in the `Isolate`.

To optimize performance and
circumvent unnecessary Isolate requests, consider utilizing the cached version of the `SharedMap` (`SharedMapCache`).

Note that the main `Isolate` is the one that created the `SharedStore` or `SharedMap` instance,
and the auxiliary `Isolate`s are the one that "gets" an instance from a `sharedReference`.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/shared_map/issues

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## Sponsor

Don't be shy, show some love, and become our [GitHub Sponsor][github_sponsors].
Your support means the world to us, and it keeps the code caffeinated! ☕✨

Thanks a million! 🚀😄

[github_sponsors]: https://github.com/sponsors/gmpassos

## License

[Apache License - Version 2.0][apache_license]

[apache_license]: https://www.apache.org/licenses/LICENSE-2.0.txt
