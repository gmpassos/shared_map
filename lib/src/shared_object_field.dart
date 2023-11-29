import 'shared_object.dart';
import 'shared_reference.dart';
import 'utils.dart';

/// [SharedObjectField] instantiator
typedef SharedFieldInstantiator<R extends SharedReference,
        O extends ReferenceableType, F extends SharedObjectField<R, O, F>>
    = F Function(String id);

/// [SharedObjectReferenceable] instantiator
typedef SharedObjectInstantiator<R extends SharedReference,
        O extends ReferenceableType>
    = O Function({R? reference, String? id});

/// Instance handler for a [SharedObjectField].
class SharedFieldInstanceHandler<R extends SharedReference,
    O extends ReferenceableType, F extends SharedObjectField<R, O, F>> {
  static final Map<(Type, Object?), SharedFieldInstanceHandler> _instances = {};

  factory SharedFieldInstanceHandler(
      {required SharedFieldInstantiator<R, O, F> fieldInstantiator,
      required SharedObjectInstantiator<R, O> sharedObjectInstantiator,
      Object? group}) {
    var fieldHandler = _instances[(F, group)] ??=
        SharedFieldInstanceHandler<R, O, F>._(
            fieldInstantiator, sharedObjectInstantiator,
            group: group);

    return fieldHandler as SharedFieldInstanceHandler<R, O, F>;
  }

  final Object? group;

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
  F fromID(String id) {
    var ref = _fieldsInstances[id];
    if (ref != null) {
      var o = ref.target;
      if (o != null) return o;
    }

    var o = fieldInstantiator(id);
    assert(identical(o, _fieldsInstances[id]?.target));
    return o;
  }

  F fromSharedObject(O o) {
    var field = fromID(o.id);
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

    if (reference != null) {
      sharedObject ??= sharedObjectInstantiator(reference: reference);
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
  final Object? _instanceHandlerGroup;

  /// The global ID of the [sharedObject].
  final String sharedObjectID;

  SharedObjectField.fromID(
    this.sharedObjectID, {
    SharedFieldInstanceHandler<R, O, F>? instanceHandler,
    SharedFieldInstantiator<R, O, F>? fieldInstantiator,
    SharedObjectInstantiator<R, O>? sharedObjectInstantiator,
    Object? instanceHandlerGroup,
  })  : _instanceHandlerGroup = instanceHandlerGroup ?? instanceHandler?.group,
        _fieldInstantiator = fieldInstantiator ??
            instanceHandler?.fieldInstantiator ??
            (throw ArgumentError.notNull('fieldInstantiator')),
        _sharedObjectInstantiator = sharedObjectInstantiator ??
            instanceHandler?.sharedObjectInstantiator ??
            (throw ArgumentError.notNull('sharedObjectInstantiator')) {
    _setupInstanceFromConstructor();
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

  void _setupInstanceFromConstructor() {
    final instanceHandler = _instanceHandler;

    assert(instanceHandler._sharedObjectExpando[this] == null);

    final id = sharedObjectID;

    assert(instanceHandler.getInstanceByID(id) == null);

    var o = instanceHandler._sharedObjectExpando[this] =
        instanceHandler.sharedObjectInstantiator(id: id);
    _sharedReference = o.sharedReference() as R;

    _fieldsInstances[id] = WeakReference(this as F);
  }

  void _setupInstance() {
    var prev = _instanceHandler.getInstanceByID(sharedObjectID);
    if (prev != null) {
      if (identical(prev, this)) {
        return;
      } else {
        throw StateError(
            "Previous `SharedStore` instance (id: $sharedObjectID) NOT identical to this instance: $prev != $this");
      }
    }

    return _setupInstanceIsolateCopy();
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

    var o = instanceHandler.sharedObjectInstantiator(reference: reference);
    instanceHandler._sharedObjectExpando[this] = o;

    _fieldsInstances[sharedObjectID] = WeakReference(this as F);
  }

  /// The [SharedObject] ([O]) of this instance. This [SharedObject] will be
  /// automatically shared among `Isolate` copies.
  ///
  /// See [isAuxiliaryInstance].
  O get sharedObject {
    _setupInstance();

    var sharedStored = _instanceHandler._sharedObjectExpando[this];
    if (sharedStored == null) {
      throw StateError(
          "After `_setupInstance`, `sharedStored` should be defined at `_sharedStoreExpando`");
    }

    return sharedStored;
  }

  String get runtimeTypeName => '$F';

  @override
  String toString() =>
      '$runtimeTypeName#$sharedObjectID${isAuxiliaryInstance ? '(aux)' : ''}';
}
