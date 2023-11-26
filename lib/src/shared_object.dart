import 'dart:math' as math;

/// Base class for [SharedStore] and [SharedMap] implementations.
abstract class SharedType {
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

  /// The ID of the shared instance.
  String get id;

  /// Returns the [SharedReference] of this instances, to instantiated it
  /// using `fromSharedReference` constructor.
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

/// Base class for objects that can be copied and passed to other `Isolate`s,
/// and automatically detected if it's a copied version ([isIsolateCopy]).
abstract class SharedObject {
  SharedObject();

  /// Returns `true` if this instance is an auxiliary copy,
  /// usually a copy passed to another `Isolate` or running in a remote client.
  bool get isAuxiliaryCopy;

  /// Returns `true` if this instance is the main/original instance.
  /// Also means that it is NOT an auxiliary copy. See [isAuxiliaryCopy].
  bool get isMainInstance => !isAuxiliaryCopy;
}

/// A NOT shared implementation of [SharedObject].
abstract class NotSharedObject {
  NotSharedObject();

  /// A [NotSharedObject] can't have an auxiliary copy.
  bool get isAuxiliaryCopy => false;

  /// A [NotSharedObject] is always the main instance. See [isAuxiliaryCopy].
  bool get isMainInstance => true;
}
