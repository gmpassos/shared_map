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
