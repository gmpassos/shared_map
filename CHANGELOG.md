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
