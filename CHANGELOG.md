## 1.1.8

- Update SharedMap instances to include `onInitialize` callback:

- New `SharedMapExtension`:
  - Added `isAuxiliaryInstance`, `isMainInstance`, `isSharedObject`, `asSharedObject`.

- test: ^1.24.9
- coverage: ^1.7.2

## 1.1.7

- `SharedObjectField`:
  - Expose getter `instanceHandler` to allow implementation override.
  - Optimize `sharedObject` resolution.

## 1.1.6

- `SharedMap`:
  - Added `update` method.

## 1.1.5

- lints: ^3.0.0

## 1.1.4

- Dart CI: Added `test_chrome`.
- `shared_map_generic.dart`:
  - Fixed `createSharedMap` with a `NotSharedStore`.

## 1.1.3

- `SharedStore`:
  - Added `getSharedObject`, `getSharedObjectReference` and `registerSharedObject`.
- `SharedObjectField`:
  - Added `sharedObjectAsync` and `isResolvingReference`.
- `SharedMap`:
  - Changed to asynchronous "constructors" (static methods): `fromID`, `fromUUID`, `from`.

## 1.1.2

- New `SharedObjectReferenceable`: `SharedObject` + `ReferenceableType`
- `SharedObjectIsolate` now implements `SharedObjectReferenceable<R>`.
- New `SharedReferenceIsolate`.
- New `SharedFieldInstanceHandler` and `SharedObjectField`.
- `SharedStoreField` and `SharedMapField`:
  - Now extends `SharedObjectField` to reuse `SharedObjectField` implementation.
- `ReferenceableType`:
  - Added `getSharedObject`, `getOrCreateSharedObject` and `disposeSharedObject`.
- Improve documentation.

## 1.1.1

- `SharedStoreIsolateAuxiliary`: fix initialization.

## 1.1.0

- Expose `SharedObject` implementation using `Isolate`:
  - `SharedObjectIsolate`:
    - Implementations: `SharedObjectIsolateMain` and `SharedObjectIsolateAuxiliary`.
  - New `SharedObjectIsolateMessage`.
    - Implementations: `SharedObjectIsolateRequestMessage` and `SharedObjectIsolateResponseMessage`.

- New libraries:
  - 'package:shared_map/shared_object.dart'
  - 'package:shared_map/shared_object_isolate.dart'

- `SharedObject`:
  - Renamed `isIsolateCopy` to `isAuxiliaryInstance`.
- Renamed `SharedType` to `ReferenceableType`.
- Renamed `SharedStoreIsolateServer` to `SharedStoreIsolateMain`.
- Renamed `SharedStoreIsolateClient` to `SharedStoreIsolateAuxiliary`.
- Renamed `SharedMapIsolateServer` to `SharedMapIsolateMain`.
- Renamed `SharedMapIsolateClient` to `SharedMapIsolateAuxiliary`.

## 1.0.10

- `SharedMapCached`:
  - Introduces async call caching for `get`, `keys`, `values`, `entries` and `length` operations,
    to avoid simultaneous asynchronous calls (fetching) for the same operation. 

- `SharedStoreIsolateServer`:
  - Fix  call to `getSharedMap<K,V>()` with correct `K` and `V` casting when requested by `SharedStoreIsolateClient`.

- Improve `SharedMap.toString` implementations.

## 1.0.9

- `SharedMap`:
  - added `onPut` and `onRemove`.

## 1.0.8

- `SharedMap`:
  - Added `values`, `entries` and `where`.

## 1.0.7

- `SharedMap`:
  - Added `clear`.
- New `FutureSharedMapExtension` and `FutureOrSharedMapExtension`.

## 1.0.6

- New `NotSharedMap`, `NotSharedStore` and `SharedMapSync`.

- Refactored `SharedMapField` and `SharedStoreField`:
  - Handle non-shared and shared instances appropriately.
  - Improved handling of isolate copies and shared references for better consistency across isolates.
 
- `SharedMap`:
  - Improved resolution and caching mechanisms to enhance performance and reduce redundant operations.

## 1.0.5

- New `SharedStoreField`.

## 1.0.4

- `SharedMap`:
  - Added `keys`, `length`, `remove` and `removeAll`.

## 1.0.3

- New `SharedMapCached`.
- Fix `SharedStoreGeneric` and `SharedMapGeneric`.
- Improve tests for `SharedStoreGeneric` and `SharedMapGeneric`.

## 1.0.2

- `SharedMap`:
  - Added `putIfAbsent`.
- `SharedType`:
  - Rename `shareReference` to `sharedReference`.

## 1.0.1

- Add documentation.

## 1.0.0

- Initial version.
