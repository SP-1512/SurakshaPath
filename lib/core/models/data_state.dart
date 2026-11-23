/// Provenance state of emergency data in SurakshaPath.
/// Distinguishes fresh network data, valid cached snapshots,
/// stale offline fallbacks, and unavailable data states.
enum DataState {
  /// Freshly fetched from network / primary source.
  fresh,

  /// Retrieved from in-memory cache within the valid TTL window.
  cached,

  /// Retrieved from cache or offline fallback after TTL expiry or network failure.
  stale,

  /// Source unreachable and no valid cached or fallback data is available.
  unavailable;

  String get label {
    switch (this) {
      case DataState.fresh:
        return 'LIVE';
      case DataState.cached:
        return 'CACHED';
      case DataState.stale:
        return 'OFFLINE FALLBACK';
      case DataState.unavailable:
        return 'UNAVAILABLE';
    }
  }

  bool get isReliable => this == DataState.fresh || this == DataState.cached;
}
