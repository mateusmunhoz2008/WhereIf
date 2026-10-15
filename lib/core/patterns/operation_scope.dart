/// Invalidates callbacks without claiming to cancel an underlying remote write.
mixin OperationScope {
  int _generation = 0;
  bool _disposed = false;

  int get operationGeneration => _generation;
  bool get operationsDisposed => _disposed;
  bool acceptsOperation(int generation) =>
      !_disposed && generation == _generation;

  void invalidateOperations() => _generation++;

  void disposeOperations() {
    _disposed = true;
    invalidateOperations();
  }
}
