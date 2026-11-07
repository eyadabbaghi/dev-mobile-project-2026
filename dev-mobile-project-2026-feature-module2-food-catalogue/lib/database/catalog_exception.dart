class CatalogException implements Exception {
  const CatalogException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
