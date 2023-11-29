/// An [ArgumentError] with a message for multiple `null` arguments.
class MultiNullArguments extends ArgumentError {
  MultiNullArguments(Iterable<String> argumentsNames)
      : super(buildMessage(argumentsNames));

  static String buildMessage(Iterable<String> argumentsNames) {
    var names = argumentsNames.map((e) => '`$e`').toList();

    if (names.isEmpty) {
      return 'Null arguments.';
    } else if (names.length == 1) {
      return 'Null ${names.first}.';
    }

    var last = names.removeLast();

    var args = names.join(', ');

    return "Null $args and $last. Please provide at least one of them.";
  }
}
