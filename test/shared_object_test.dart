@TestOn('vm')
@Timeout(Duration(minutes: 5))
import 'dart:async';
import 'dart:isolate';

import 'package:shared_map/shared_map.dart';
import 'package:shared_map/shared_object_isolate.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('SharedObjectIsolate (MyCounter)', () {
    test('basic', () async {
      var store1 = SharedStore('store1');

      var c1 = await MyCounter.fromID(store1, "c1");

      expect(c1.get(), equals(0));
      expect(c1.set(100), equals(100));
      expect(c1.get(), equals(100));
      expect(c1.increment(1), equals(101));
      expect(c1.get(), equals(101));

      final ref = c1.sharedReference();
      expect(ref.id, equals('c1'));

      var n1 = await Isolate.run(() async {
        var c1 = MyCounter.fromReference(ref);

        var n1 = await c1.get();
        if (n1 != 101) {
          throw StateError("expect: 101 ; got: $n1");
        }

        return n1;
      });

      expect(n1, equals(101));

      var n2 = await Isolate.run(() async {
        var c1 = MyCounter.fromReference(ref);

        var n2 = await c1.set(200);
        if (n2 != 200) {
          throw StateError("expect: 200 ; got: $n2");
        }

        return n2;
      });

      expect(n2, equals(200));

      var n3 = await Isolate.run(() async {
        var c1 = MyCounter.fromReference(ref);

        var n3 = await c1.increment(3);
        if (n3 != 203) {
          throw StateError("expect: 203 ; got: $n3");
        }

        return n3;
      });

      expect(n3, equals(203));

      final field = MyCounterField.fromSharedObject(c1);

      expect(field.sharedObjectID, equals('c1'));
      expect(field.isMainInstance, isTrue);
      expect(field.isAuxiliaryInstance, isFalse);
      expect(identical(field.sharedObject, c1), isTrue);

      var n4 = await Isolate.run(() async {
        if (!field.isAuxiliaryInstance || field.isMainInstance) {
          throw StateError("Expect AuxiliaryInstance (field): $field");
        }

        var c1 = field.sharedObject;

        if (!field.isAuxiliaryInstance || field.isMainInstance) {
          throw StateError("Expect AuxiliaryInstance (field): $field");
        }

        if (!c1.isAuxiliaryInstance || c1.isMainInstance) {
          throw StateError("Expect AuxiliaryInstance (counter): $c1");
        }

        var n4 = await c1.increment(5);
        if (n4 != 208) {
          throw StateError("expect: 208 ; got: $n4");
        }

        return n4;
      });

      expect(n4, equals(208));

      final counterID = c1.id;
      final store1Ref = store1.sharedReference();
      final field2 = MyCounterField.fromID(counterID, store1Ref);

      expect(identical(field2.sharedObject, c1), isTrue);
      expect(field2.sharedObject.get(), equals(208));

      var n5 = await Isolate.run(() async {
        final field3 = MyCounterField.fromID(counterID, store1Ref);

        if (!field3.isResolvingReference) {
          throw StateError("Expect `isResolvingReference = true` for: $field3");
        }

        var counter2 = await field3.sharedObjectAsync;
        var n5 = await counter2.get();
        return n5;
      });

      expect(n5, equals(208));
    });
  });
}

abstract class MyCounter implements SharedObjectIsolate<MyCounterReference> {
  /*
  factory MyCounter(SharedStore sharedStore, String id) {
    var counter = ReferenceableType.getOrCreateSharedObject<MyCounter>(id,
        ifAbsent: (id) => _MyCounterMain(sharedStore, id));

    var counter2 = ReferenceableType.getSharedObject<MyCounter>(id);

    assert(identical(counter2, counter));

    return counter;
  }
   */

  static FutureOr<MyCounter> fromID(SharedStore sharedStore, String id) {
    var o = sharedStore.getSharedObject<MyCounter>(id);

    if (o is Future<MyCounter?>) {
      return o.then((o) {
        if (o != null) return o;
        return _getReferenceOrCreate(sharedStore, id);
      });
    }

    if (o != null) return o;
    return _getReferenceOrCreate(sharedStore, id);
  }

  static Future<MyCounter> _getReferenceOrCreate(
      SharedStore sharedStore, String id) async {
    var ref = await sharedStore
        .getSharedObjectReference<MyCounter, MyCounterReference>(id);

    if (ref != null) {
      return _MyCounterAuxiliary(sharedStore, id, ref.serverPort);
    } else {
      return _MyCounterMain(sharedStore, id);
    }
  }

  factory MyCounter.fromReference(MyCounterReference reference) {
    var sharedStore =
        SharedStore.fromSharedReference(reference.sharedStoreReference);

    var counterAsync = sharedStore.getSharedObject<MyCounter>(reference.id);
    if (counterAsync is MyCounter) {
      return counterAsync;
    }

    var counter = ReferenceableType.getOrCreateSharedObject<MyCounter>(
        reference.id,
        ifAbsent: (id) => _MyCounterAuxiliary(
            SharedStore.fromSharedReference(reference.sharedStoreReference),
            id,
            reference.serverPort));

    assert(identical(
        ReferenceableType.getSharedObject<MyCounter>(reference.id), counter));

    return counter;
  }

  static FutureOr<MyCounter> from(
      {MyCounterReference? reference,
      String? id,
      SharedStoreReference? sharedStoreReference,
      SharedStore? sharedStore,
      String? sharedStoreID}) {
    if (reference != null) {
      return MyCounter.fromReference(reference);
    }

    if (id != null) {
      sharedStore ??=
          SharedStore.from(reference: sharedStoreReference, id: sharedStoreID);
      return MyCounter.fromID(sharedStore, id);
    }

    throw StateError(
        "Null values for `reference`, `sharedStore` and `id` parameters! Please provide `reference` or `sharedStore` and `id`");
  }

  SharedStore get sharedStore;

  FutureOr<int> get();

  FutureOr<int> set(int c);

  FutureOr<int> increment([int amount = 1]);
}

enum MyCounterOperation {
  get,
  set,
  increment,
}

class _MyCounterMain extends SharedObjectIsolateMain<MyCounterReference>
    implements MyCounter {
  final SharedStore _sharedStore;

  @override
  SharedStore get sharedStore => _sharedStore;

  int _counter;

  _MyCounterMain(this._sharedStore, super.id, {int counter = 0})
      : _counter = counter {
    _sharedStore.registerSharedObject<MyCounter>(this);
  }

  @override
  MyCounterReference sharedReference() =>
      MyCounterReference(id, _sharedStore.sharedReference(), isolateSendPort);

  @override
  void onReceiveIsolateRequestMessage(SharedObjectIsolateRequestMessage m) {
    final args = m.args;
    final op = args[0] as MyCounterOperation;

    Object? result;

    switch (op) {
      case MyCounterOperation.get:
        {
          result = get();
        }
      case MyCounterOperation.set:
        {
          var c = args[1];
          result = set(c);
        }
      case MyCounterOperation.increment:
        {
          var n = args[1];
          result = increment(n);
        }
    }

    m.sendResponse(result);
  }

  @override
  int get() => _counter;

  @override
  int set(int c) => _counter = c;

  @override
  int increment([int amount = 1]) => _counter += amount;

  @override
  String toString() => 'MyCounterMain#$id{counter: $_counter}';
}

class _MyCounterAuxiliary
    extends SharedObjectIsolateAuxiliary<MyCounterReference, int>
    implements MyCounter {
  final SharedStore _sharedStore;

  @override
  SharedStore get sharedStore => _sharedStore;

  @override
  SendPort serverPort;

  _MyCounterAuxiliary(this._sharedStore, super.id, this.serverPort) {
    _sharedStore.registerSharedObject<MyCounter>(this);
  }

  @override
  MyCounterReference sharedReference() =>
      MyCounterReference(id, _sharedStore.sharedReference(), serverPort);

  @override
  Future<int> get() => sendRequestNotNull([MyCounterOperation.get]);

  @override
  Future<int> set(int c) => sendRequestNotNull([MyCounterOperation.set, c]);

  @override
  Future<int> increment([int amount = 1]) =>
      sendRequestNotNull([MyCounterOperation.increment, amount]);

  @override
  String toString() => 'MyCounterAuxiliary#$id';
}

class MyCounterReference extends SharedReferenceIsolate {
  final SharedStoreReference sharedStoreReference;

  MyCounterReference(super.id, this.sharedStoreReference, super.serverPort);
}

class MyCounterField
    extends SharedObjectField<MyCounterReference, MyCounter, MyCounterField> {
  /// Resolves the [SharedFieldInstanceHandler] for each [SharedStore] of [sharedStoreReference].
  static SharedFieldInstanceHandler<MyCounterReference, MyCounter,
      MyCounterField> _instanceHandler(
          SharedStoreReference sharedStoreReference) =>
      SharedFieldInstanceHandler(
        fieldInstantiator: (id, {sharedObjectReference}) =>
            MyCounterField._fromID(id, sharedStoreReference,
                sharedObjectReference: sharedObjectReference),
        sharedObjectInstantiator: ({reference, id}) => MyCounter.from(
            reference: reference,
            id: id,
            sharedStoreReference: sharedStoreReference),
        group: (SharedStore, sharedStoreReference.id),
      );

  factory MyCounterField.fromID(
          String id, SharedStoreReference sharedStoreReference) =>
      _instanceHandler(sharedStoreReference).fromID(id);

  factory MyCounterField.fromSharedObject(MyCounter o) =>
      _instanceHandler(o.sharedStore.sharedReference()).fromSharedObject(o);

  final SharedStoreField _sharedStoreField;

  MyCounterField._fromID(super.id, SharedStoreReference sharedStoreReference,
      {super.sharedObjectReference})
      : _sharedStoreField =
            SharedStoreField.from(sharedStoreReference: sharedStoreReference),
        super.fromID(instanceHandler: _instanceHandler(sharedStoreReference));

  SharedStore get sharedStore => _sharedStoreField.sharedStore;
}
