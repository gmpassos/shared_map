@TestOn('vm')
@Timeout(Duration(minutes: 5))
import 'dart:async';
import 'dart:isolate';

import 'package:shared_map/shared_object.dart';
import 'package:shared_map/src/shared_object_isolate.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('SharedObjectIsolate (MyCounter)', () {
    test('basic', () async {
      var c1 = MyCounter("c1");

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

      final field2 = MyCounterField.fromID(c1.id);

      expect(identical(field2.sharedObject, c1), isTrue);
    });
  });
}

abstract class MyCounter implements SharedObjectIsolate<MyCounterReference> {
  factory MyCounter(String id) => ReferenceableType.getOrCreateSharedObject(id,
      ifAbsent: _MyCounterMain.new);

  factory MyCounter.fromReference(MyCounterReference reference) =>
      ReferenceableType.getOrCreateSharedObject(reference.id,
          ifAbsent: (id) => _MyCounterAuxiliary(id, reference.serverPort));

  factory MyCounter.from({MyCounterReference? reference, String? id}) {
    if (reference != null) {
      return MyCounter.fromReference(reference);
    }

    if (id != null) {
      return MyCounter(id);
    }

    throw StateError(
        "Null values for both `reference` and `id` parameters! Please provide at least one.");
  }

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
  int _counter;

  _MyCounterMain(super.id, {int counter = 0}) : _counter = counter;

  @override
  MyCounterReference sharedReference() =>
      MyCounterReference(id, isolateSendPort);

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
  @override
  SendPort serverPort;

  _MyCounterAuxiliary(super.id, this.serverPort);

  @override
  MyCounterReference sharedReference() => MyCounterReference(id, serverPort);

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
  MyCounterReference(super.id, super.serverPort);
}

class MyCounterField
    extends SharedObjectField<MyCounterReference, MyCounter, MyCounterField> {
  static final _instanceHandler =
      SharedFieldInstanceHandler<MyCounterReference, MyCounter, MyCounterField>(
    fieldInstantiator: MyCounterField._fromID,
    sharedObjectInstantiator: MyCounter.from,
  );

  MyCounterField._fromID(String id)
      : super.fromID(id, instanceHandler: _instanceHandler);

  factory MyCounterField.fromID(String id) => _instanceHandler.fromID(id);

  factory MyCounterField.fromSharedObject(MyCounter o) =>
      _instanceHandler.fromSharedObject(o);
}