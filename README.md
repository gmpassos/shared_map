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
```

Output:
```text
va1: null
va2: 11
sharedMapReference: SharedMapReference{id: m1, sharedStore: {id: t1}}
va3: 11
va4: 111
sharedMapID: m1
shareStoreReference: SharedStoreReference{id: t1}
va5: 222
va6: 222
```

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
