/// Typed exceptions repositories throw (claude.md Coding Conventions —
/// never a raw try/catch scattered inside a widget's build()).
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NoConnectionException implements Exception {
  const NoConnectionException([this.message = 'No internet connection.']);
  final String message;

  @override
  String toString() => message;
}
