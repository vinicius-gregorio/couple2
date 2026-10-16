/// One deadline for every HTTP call and every provider read.
///
/// A slow response is still in flight until this elapses. Nothing in the
/// client may use a shorter per-call timeout.
const requestTimeout = Duration(seconds: 12);
