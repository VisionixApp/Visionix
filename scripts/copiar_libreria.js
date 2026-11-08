// Copia la librería de reconocimiento facial y sus modelos dentro de www/ para que la app funcione sin internet.
// Se ejecuta con: npm run vendor  (requiere haber hecho npm install; es tolerante: si falla, la app usa los CDN al abrirse con internet)
const fs = require('fs');
const path = require('path');

const raiz = path.join(__dirname, '..');
const paquete = path.join(raiz, 'node_modules', '@vladmandic', 'face-api');

function copiarDir(origen, destino) {
  fs.mkdirSync(destino, { recursive: true });
  for (const e of fs.readdirSync(origen, { withFileTypes: true })) {
    const o = path.join(origen, e.name), d = path.join(destino, e.name);
    if (e.isDirectory()) copiarDir(o, d); else fs.copyFileSync(o, d);
  }
}

try {
  if (!fs.existsSync(paquete)) throw new Error('No está instalado @vladmandic/face-api (corre "npm install" primero)');
  const lib = path.join(paquete, 'dist', 'face-api.js');
  if (!fs.existsSync(lib)) throw new Error('No se encontró dist/face-api.js dentro del paquete');
  fs.mkdirSync(path.join(raiz, 'www', 'vendor'), { recursive: true });
  fs.copyFileSync(lib, path.join(raiz, 'www', 'vendor', 'face-api.js'));
  const modelos = path.join(paquete, 'model');
  if (!fs.existsSync(modelos)) throw new Error('No se encontró la carpeta model/ dentro del paquete');
  copiarDir(modelos, path.join(raiz, 'www', 'model'));
  const n = fs.readdirSync(path.join(raiz, 'www', 'model')).length;
  console.log('Librería y modelos copiados a www/ (' + n + ' archivos de modelo).');
} catch (e) {
  console.warn('AVISO: no se copió la librería local → ' + e.message);
  console.warn('La app seguirá funcionando, pero necesitará internet la primera vez para descargar los modelos.');
}

// Librería de Supabase (para la nube): si no se copia, la app la descarga de un CDN al abrirse con internet.
try {
  const sb = path.join(raiz, 'node_modules', '@supabase', 'supabase-js', 'dist', 'umd', 'supabase.js');
  if (!fs.existsSync(sb)) throw new Error('No se encontró @supabase/supabase-js/dist/umd/supabase.js (corre "npm install" primero)');
  fs.mkdirSync(path.join(raiz, 'www', 'vendor'), { recursive: true });
  fs.copyFileSync(sb, path.join(raiz, 'www', 'vendor', 'supabase.js'));
  console.log('Librería de Supabase copiada a www/vendor/supabase.js');
} catch (e) {
  console.warn('AVISO: no se copió la librería de Supabase → ' + e.message);
}
