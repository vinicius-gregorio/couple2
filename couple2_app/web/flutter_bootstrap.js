{{flutter_js}}
{{flutter_build_config}}

(function () {
  // About 3 minutes. A slow 3G load still shows the heart; this only offers
  // a reload if the engine never reaches the first frame.
  var kSplashLimitMs = 180000;
  var settled = false;
  var timer = 0;

  function fallbackBaseUrl() {
    return new URL('fallback_fonts/', document.baseURI).href;
  }

  function settle() {
    settled = true;
    if (timer) {
      clearTimeout(timer);
      timer = 0;
    }
  }

  function showSplashFailure() {
    if (settled) return;
    settle();
    var splash = document.getElementById('flutter-splash');
    if (!splash) return;
    var spinner = splash.querySelector('.spinner');
    if (spinner) spinner.hidden = true;
    var failure = document.getElementById('flutter-splash-failure');
    if (failure) failure.hidden = false;
  }

  function watchSplashRemoval() {
    if (!window.MutationObserver) return;
    var observer = new MutationObserver(function () {
      if (!document.getElementById('flutter-splash')) {
        settle();
        observer.disconnect();
      }
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  function watchEntrypointErrors() {
    if (!window.MutationObserver) return;
    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        mutation.addedNodes.forEach(function (node) {
          if (!node || node.tagName !== 'SCRIPT') return;
          var src = node.src || '';
          if (src.indexOf('main.dart.js') === -1) return;
          node.addEventListener('error', showSplashFailure);
        });
      });
    });
    observer.observe(document.head, { childList: true });
  }

  watchSplashRemoval();
  watchEntrypointErrors();
  timer = setTimeout(showSplashFailure, kSplashLimitMs);

  var config = { fontFallbackBaseUrl: fallbackBaseUrl() };
  var loading = _flutter.loader.load({
    config: config,
    onEntrypointLoaded: function (engineInitializer) {
      Promise.resolve(engineInitializer.initializeEngine(config))
        .then(function (appRunner) {
          return appRunner.runApp();
        })
        .catch(showSplashFailure);
    },
  });
  if (loading && typeof loading.catch === 'function') {
    loading.catch(showSplashFailure);
  }
})();
