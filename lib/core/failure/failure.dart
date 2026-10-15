sealed class Failure implements Exception {
  final String msg;
  Failure(this.msg);

  @override
  String toString() => '$runtimeType: $msg';
}

class PendingSyncFailure extends Failure {
  PendingSyncFailure() : super('networkWritePending');
}

class DefaultFailure extends Failure {
  DefaultFailure([String? msg]) : super(msg ?? 'fieldsRequired');
}

class ValidationError extends Failure {
  ValidationError(super.msg);
}

class InvalidInputFailure extends Failure {
  InvalidInputFailure([String? msg]) : super(msg ?? 'fieldsRequired');
}

class NotFoundFailure extends Failure {
  NotFoundFailure([String? msg]) : super(msg ?? 'notFound');
}

class UnauthenticatedFailure extends Failure {
  UnauthenticatedFailure([String? msg]) : super(msg ?? 'unauthenticated');
}

class ForbiddenFailure extends Failure {
  ForbiddenFailure([String? msg]) : super(msg ?? 'forbidden');
}

class RemoteFailure extends Failure {
  RemoteFailure([String? msg]) : super(msg ?? 'remoteError');
}
