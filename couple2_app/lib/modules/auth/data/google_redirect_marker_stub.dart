bool _pending = false;

void markGoogleRedirectPending() => _pending = true;

void clearGoogleRedirectPending() => _pending = false;

bool googleRedirectIsPending() => _pending;
