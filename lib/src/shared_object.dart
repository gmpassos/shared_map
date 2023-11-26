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

/// A NOT shared implementation of [SharedObject].
abstract class NotSharedObject extends SharedObject {
  /// A [NotSharedObject] can't have an auxiliary instance.
  @override
  bool get isAuxiliaryInstance => false;

  /// A [NotSharedObject] is always the main instance. See [isAuxiliaryCopy].
  @override
  bool get isMainInstance => true;
}

/// Base class for shared objects.
/// See [isAuxiliaryInstance].
abstract class SharedObject {
  /// Returns `true` if this is an auxiliary instance,
  /// usually a copy passed to another `Isolate` or running in a remote client.
  bool get isAuxiliaryInstance;

  /// Returns `true` if this instance is the main/original instance.
  /// Also means that it is NOT an auxiliary instance. See [isAuxiliaryInstance].
  bool get isMainInstance => !isAuxiliaryInstance;
}

/// The main ("server") side implementation of a [SharedObject].
mixin SharedObjectMain implements SharedObject {
  @override
  bool get isAuxiliaryInstance => false;

  @override
  bool get isMainInstance => true;
}

/// The auxiliary ("client") side implementation of a [SharedObject].
mixin class SharedObjectAuxiliary implements SharedObject {
  @override
  bool get isAuxiliaryInstance => true;

  @override
  bool get isMainInstance => false;
}
