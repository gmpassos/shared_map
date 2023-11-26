import 'dart:math' as math;

/// Base class for [SharedStore] and [SharedMap] implementations.
abstract class ReferenceableType {
  static int _uuidCount = 0;

  /// Creates an UUID (Universally Unique Identifier).
  /// See [SharedStore.fromUUID] and [SharedMap.fromUUID].
  static String newUUID() {
    var c = ++_uuidCount;
    var now = DateTime.now();

    const range = 1999999999;

    var rand1 = math.Random();
    var rand2 = math.Random(now.microsecondsSinceEpoch);

    var seed3 = (rand1.nextInt(range) ^ rand2.nextInt(range)).abs() ^ c;
    var rand3 = math.Random(seed3);

    var n1 = rand1.nextInt(range);
    var n2 = rand2.nextInt(range);
    var n3 = rand3.nextInt(range);

    var n4 = (rand1.nextInt(range) ^ rand2.nextInt(range)).abs();
    var n5 = (rand1.nextInt(range) ^ rand3.nextInt(range)).abs();
    var n6 = (rand2.nextInt(range) ^ rand3.nextInt(range)).abs();

    return 'UUID-$n1-$n2-$n3-$n4-$n5-$n6-$c';
  }

  /// The ID of the referenceable instance.
  String get id;

  /// Returns the [SharedReference] of this instances,
  /// to instantiate it using a `fromSharedReference` constructor.
  SharedReference sharedReference();
}

/// Base class for [SharedReference] implementations.
abstract class SharedReference {
  /// The ID of the referenced instance.
  final String id;

  SharedReference(this.id);

  /// The JSON of this [SharedReference].
  Map<String, dynamic> toJson();
}
