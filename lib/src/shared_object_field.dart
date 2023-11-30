import 'dart:async';

import 'shared_object.dart';
import 'shared_reference.dart';
import 'utils.dart';

/// [SharedObjectField] instantiator
typedef SharedFieldInstantiator<R extends SharedReference,
        O extends ReferenceableType, F extends SharedObjectField<R, O, F>>
    = F Function(String id, {R? sharedObjectReference});

/// [SharedObjectReferenceable] instantiator
typedef SharedObjectInstantiator<R extends SharedReference,
        O extends ReferenceableType>
    = FutureOr<O> Function({R? reference, String? id});

/// Instance handler for a [SharedObjectField].
class SharedFieldInstanceHandler<R extends SharedReference,
    O extends ReferenceableType, F extends SharedObjectField<R, O, F>> {
  static final Map<(Type, Object?), SharedFieldInstanceHandler> _instances = {};

  factory SharedFieldInstanceHandler(
      {required SharedFieldInstantiator<R, O, F> fieldInstantiator,
      required SharedObjectInstantiator<R, O> sharedObjectInstantiator,
      (Type, Object?)? group}) {
    var fieldHandler = _instances[(F, group)] ??=
        SharedFieldInstanceHandler<R, O, F>._(
            fieldInstantiator, sharedObjectInstantiator,
            group: group);

    return fieldHandler as SharedFieldInstanceHandler<R, O, F>;
  }

  final (Type, Object?)? group;

  final Map<String, WeakReference<F>> _fieldsInstances = {};

  final SharedFieldInstantiator<R, O, F> fieldInstantiator;

  final SharedObjectInstantiator<R, O> sharedObjectInstantiator;

  SharedFieldInstanceHandler._(
      this.fieldInstantiator, this.sharedObjectInstantiator,
      {this.group});

  /// Returns a cached [SharedObjectField] instance by [id].
  F? getInstanceByID(String id) {
    final ref = _fieldsInstances[id];
    if (ref == null) return null;

    final prev = ref.target;
    if (prev == null) {
      _fieldsInstances.remove(id);
      return null;
    }

    return prev;
  }

  /// Creates a [SharedObjectField] with [id].
  F fromID(String id, {R? reference}) {
    var ref = _fieldsInstances[id];
    if (ref != null) {
      var o = ref.target;
      if (o != null) return o;
    }

    var o = fieldInstantiator(id, sharedObjectReference: reference);
    assert(identical(o, _fieldsInstances[id]?.target));
    return o;
  }

  F fromSharedObject(O o) {
    var field = fromID(o.id, reference: o.sharedReference() as R);
    var o2 = field.sharedObject;

    if (!identical(o, o2)) {
      throw StateError(
          "Parameter `$O` instance is NOT the same of `$F.sharedObject`> $o != ${field.sharedObject}");
    }
    return field;
  }

  F from({F? field, R? reference, O? sharedObject, String? id}) {
    return tryFrom(
            field: field,
            reference: reference,
            sharedObject: sharedObject,
            id: id) ??
        (throw MultiNullArguments(
            ['field', 'reference', 'sharedObject', 'id']));
  }

  F? tryFrom({F? field, R? reference, O? sharedObject, String? id}) {
    if (field != null) {
      return field;
    }

    if (reference != null && sharedObject == null) {
      var oAsync = sharedObjectInstantiator(reference: reference);
      if (oAsync is O) {
        sharedObject = oAsync;
      }
    }

    if (sharedObject != null) {
      return fromSharedObject(sharedObject);
    }

    if (id != null) {
      return fieldInstantiator(id);
    }

    return null;
  }

  final Expando<O> _sharedObjectExpando = Expando();
}

/// Base class for [SharedObjectField] implementation.
abstract class SharedObjectField<
    R extends SharedReference,
    O extends ReferenceableType,
    F extends SharedObjectField<R, O, F>> extends SharedObject {
  final SharedFieldInstantiator<R, O, F> _fieldInstantiator;
  final SharedObjectInstantiator<R, O> _sharedObjectInstantiator;
  final (Type, Object?)? _instanceHandlerGroup;

  /// The global ID of the [sharedObject].
  final String sharedObjectID;

  SharedObjectField.fromID(
    this.sharedObjectID, {
    R? sharedObjectReference,
    SharedFieldInstanceHandler<R, O, F>? instanceHandler,
    SharedFieldInstantiator<R, O, F>? fieldInstantiator,
    SharedObjectInstantiator<R, O>? sharedObjectInstantiator,
    (Type, Object?)? instanceHandlerGroup,
  })  : _instanceHandlerGroup = instanceHandlerGroup ?? instanceHandler?.group,
        _fieldInstantiator = fieldInstantiator ??
            instanceHandler?.fieldInstantiator ??
            (throw ArgumentError.notNull('fieldInstantiator')),
        _sharedObjectInstantiator = sharedObjectInstantiator ??
            instanceHandler?.sharedObjectInstantiator ??
            (throw ArgumentError.notNull('sharedObjectInstantiator')) {
    _setupInstanceFromConstructor(sharedObjectReference);
  }

  static final Expando<SharedFieldInstanceHandler> _instanceHandlerExpando =
      Expando();

  SharedFieldInstanceHandler<R, O, F> get _instanceHandler =>
      (_instanceHandlerExpando[this] ??= SharedFieldInstanceHandler<R, O, F>(
        fieldInstantiator: _fieldInstantiator,
        sharedObjectInstantiator: _sharedObjectInstantiator,
        group: _instanceHandlerGroup,
      )) as SharedFieldInstanceHandler<R, O, F>;

  Map<String, WeakReference<F>> get _fieldsInstances =>
      _instanceHandler._fieldsInstances;

  R? _sharedReference;

  /// The [SharedReference] ([R]) of the [SharedObject].
  R get sharedReference => _sharedReference!;

  static final Expando<Future<Object>> _resolvingReferenceAsyncExpando =
      Expando();

  bool _resolvingReference = false;

  /// Returns `true` if it's asynchronously resolving the internal reference
  /// to the [SharedObject]. See [sharedObjectAsync].
  bool get isResolvingReference => _resolvingReference;

  Future<O>? get _resolvingReferenceAsync =>
      _resolvingReferenceAsyncExpando[this]?.then((o) => o as O);

  void _setupInstanceFromConstructor(R? sharedObjectReference) {
    final instanceHandler = _instanceHandler;
    final sharedObjectExpando = instanceHandler._sharedObjectExpando;

    assert(sharedObjectExpando[this] == null);

    final id = sharedObjectID;

    assert(instanceHandler.getInstanceByID(id) == null);

    _fieldsInstances[id] = WeakReference(this as F);

    var o = sharedObjectExpando[this];

    if (o == null) {
      var oAsync = instanceHandler.sharedObjectInstantiator(
          id: id, reference: sharedObjectReference);

      if (oAsync is Future<O>) {
        _resolvingReference = true;
        _resolvingReferenceAsyncExpando[this] = oAsync.then((o) {
          sharedObjectExpando[this] = o;
          _sharedReference = o.sharedReference() as R;
          _resolvingReference = false;
          _resolvingReferenceAsyncExpando[this] = null;
          return o;
        });
        return;
      } else {
        o = oAsync;
      }
    }

    sharedObjectExpando[this] = o;
    _sharedReference = o.sharedReference() as R;
  }

  void _setupInstance() {
    var prev = _instanceHandler.getInstanceByID(sharedObjectID);

    if (prev == null) {
      _setupInstanceIsolateCopy();
    } else {
      assert(identical(prev, this),
          "Previous `SharedStore` instance (id: $sharedObjectID) NOT identical to this instance: $prev != $this");
    }
  }

  bool _isolateCopy = false;

  @override
  bool get isAuxiliaryInstance {
    _setupInstance();
    return _isolateCopy;
  }

  void _setupInstanceIsolateCopy() {
    final instanceHandler = _instanceHandler;

    assert(instanceHandler._sharedObjectExpando[this] == null);

    _isolateCopy = true;

    var reference = _sharedReference ??
        (throw StateError(
            "An `Isolate` copy should have `_reference` defined!"));

    var o = instanceHandler.sharedObjectInstantiator(reference: reference) as O;
    instanceHandler._sharedObjectExpando[this] = o;

    _fieldsInstances[sharedObjectID] = WeakReference(this as F);
  }

  /// The [SharedObject] ([O]) of this instance. This [SharedObject] will be
  /// automatically shared among `Isolate` copies.
  ///
  /// See [isAuxiliaryInstance], [isResolvingReference] and [sharedObjectAsync].
  O get sharedObject {
    _setupInstance();

    var o = _instanceHandler._sharedObjectExpando[this];
    if (o == null) {
      if (_resolvingReference) {
        throw StateError(
            "Trying to get `sharedObject` before it's resolved. See `isResolvingReference` and `sharedObjectAsync`.");
      } else {
        throw StateError(
            "After `_setupInstance`, `sharedObject` should be defined at `_sharedStoreExpando` (resolvingReference: $_resolvingReference)");
      }
    }

    return o;
  }

  /// Asynchronous version of [sharedObject].
  /// See [isResolvingReference].
  FutureOr<O> get sharedObjectAsync {
    if (!_resolvingReference) {
      return sharedObject;
    }

    return _resolvingReferenceAsync!;
  }

  String get runtimeTypeName => '$F';

  @override
  String toString() =>
      '$runtimeTypeName#$sharedObjectID${isAuxiliaryInstance ? '(aux)' : ''}';
}
