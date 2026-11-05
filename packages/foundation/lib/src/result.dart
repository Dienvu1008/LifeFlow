/// Minimal Result type for expected (non-exceptional) failures.
/// Skeleton placeholder; the full sealed type lands in P01.
sealed class Result<T, E> {
  const Result();
}

class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);
  final T value;
}

class Err<T, E> extends Result<T, E> {
  const Err(this.error);
  final E error;
}
