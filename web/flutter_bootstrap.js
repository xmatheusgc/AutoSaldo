{{flutter_js}}
{{flutter_build_config}}

// Carregar Flutter sem Service Worker e renovar fontes/assets em cache antigo de deploy anterior
(async function () {
  const ASSET_CACHE_VERSION = '20261127_1';
  try {
    if ('serviceWorker' in navigator) {
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map((r) => r.unregister()));
    }
    if (window.localStorage && localStorage.getItem('autosaldo_asset_v') !== ASSET_CACHE_VERSION) {
      const bust = Promise.allSettled([
        fetch('assets/fonts/MaterialIcons-Regular.otf', { cache: 'reload' }),
        fetch('assets/FontManifest.json', { cache: 'reload' }),
        fetch('main.dart.js', { cache: 'reload' }),
      ]);
      const timeout = new Promise((resolve) => setTimeout(resolve, 2500));
      await Promise.race([bust, timeout]);
      localStorage.setItem('autosaldo_asset_v', ASSET_CACHE_VERSION);
    }
  } catch (_) {
    // Nunca bloquear o boot do app caso offline/storage restrito
  }
  _flutter.loader.load();
})();

