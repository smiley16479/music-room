class APIException implements Exception {
  final int statusCode;
  final String message;

  APIException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'APIException: $statusCode - $message';
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
