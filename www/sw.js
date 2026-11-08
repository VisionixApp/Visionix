/* Service worker de "VISIONIX (prueba)": app y modelos de reconocimiento disponibles sin internet.
   Solo se usa al abrir la app desde un navegador (PWA). En el APK los archivos ya van incluidos. */
const VERSION = 'visionix-v4';
const APP = ['./', './index.html', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png', './icons/icon-maskable-512.png'];
const CDNS = ['cdn.jsdelivr.net', 'unpkg.com', 'vladmandic.github.io'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(APP)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const propio = url.origin === self.location.origin;
  const cdn = CDNS.includes(url.hostname);
  if (!propio && !cdn) return;

  // Librería y modelos (propios o de CDN): primero caché; si no está, red y se guarda para la próxima vez.
  const pesado = cdn || /\/(vendor|model)\//.test(url.pathname);
  if (pesado) {
    e.respondWith(
      caches.open(VERSION).then((c) =>
        c.match(req).then((hit) => hit || fetch(req).then((r) => {
          if (r && (r.ok || r.type === 'opaque')) c.put(req, r.clone());
          return r;
        }))
      )
    );
    return;
  }

  // Archivos de la app: red primero (para recibir actualizaciones); sin internet, la copia guardada.
  e.respondWith(
    fetch(req).then((r) => {
      if (r && r.ok) { const copia = r.clone(); caches.open(VERSION).then((c) => c.put(req, copia)); }
      return r;
    }).catch(() => caches.match(req).then((hit) => hit || (req.mode === 'navigate' ? caches.match('./index.html') : Response.error())))
  );
});
