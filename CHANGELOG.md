## 1.1.0

- `SharedObject`:
  - Renamed `isIsolateCopy` to `isAuxiliaryInstance`.

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
