# VISIONIX (prueba) — app para Android

Esta carpeta convierte la versión de prueba en una **app instalable en el celular** que trabaja **siempre con una base de datos en Supabase**:
los datos de la escuela (alumnos, rostros, asistencias, avisos, personal) viven en tu proyecto de Supabase y **no** en el dispositivo, así que administradores y personal ven lo mismo en tiempo real desde varios dispositivos.
La app completa vive en un solo archivo: `www/index.html`. La conexión con tu proyecto se escribe una sola vez en `www/config.js` (no se pide en pantalla). El resto de los archivos sirven para empaquetarla como APK.

> **Aviso importante.** Preparé y probé la aplicación y la base de datos de forma automática, pero en el entorno donde trabajé **no hay internet, ni Android, ni un Supabase real**:
> la seguridad por fila y las funciones SQL se probaron en un PostgreSQL 16 real, y la conexión se probó con un cliente de Supabase *simulado*.
> Nunca se ha corrido contra un proyecto real de Supabase, ni se compiló el APK, ni se abrió en un teléfono. Si algún paso falla, copia el mensaje (o el de la consola del navegador) y se corrige.

---

## Paso 1 — Preparar Supabase (una sola vez, unos 15 minutos)

1. **Crea la cuenta y el proyecto.** Entra a <https://supabase.com>, crea una cuenta (gratis) y un proyecto nuevo (elige una región cercana y guarda la contraseña de la base de datos; no la necesitas en la app).
2. **Crea las tablas y los permisos.** En el proyecto abre **SQL Editor → New query**, pega **todo** el contenido de `supabase/esquema.sql` y pulsa **Run**. Debe terminar sin errores (se puede ejecutar otra vez sin romper nada).
3. **Ajusta la autenticación** (*Authentication*; los nombres del menú pueden variar un poco según la versión del panel):
   - **Desactiva «Confirm email»** (Authentication → Sign In / Providers → Email). Hazlo **antes** de crear el primer administrador en la app; si no, la cuenta queda sin confirmar y no puede entrar. Si ya creaste una así, bórrala en Authentication → Users.
   - **Activa «Allow anonymous sign-ins»** (Authentication → Sign In / Providers). El personal autorizado lo usa para entrar sin correo; sin esto, su inicio de sesión falla.
   - Deja activado «Allow new users to sign up» (lo usan los administradores al crear su cuenta en la app).
4. **Copia dos datos del proyecto** (**Project Settings → API** o *API Keys*): la **Project URL** (`https://xxxx.supabase.co`) y la clave **pública** (`anon` o `publishable`; empieza con `eyJ…` o `sb_publishable_…`).
   - ⚠ **Nunca uses la clave `service_role` ni la `secret`**: dan acceso total a la base de datos y no deben ir en una app. VISIONIX la rechaza.
   - La clave pública *está pensada para ir dentro de la app*: lo que protege los datos son los permisos de la base de datos (`esquema.sql`), no esconder esa clave. Por eso puede viajar en el repositorio o en la APK.

> No hay que crear al administrador en Supabase: se crea dentro de la app (ver «Cómo entrar», más abajo), pidiendo la **clave de producto**.
> En esta versión de prueba la clave es **`V15I0N1X`** y viene ya guardada en la base de datos (tabla `clave_producto`). La propia app la muestra como «comentario de prueba» en esa pantalla.
> Si quieres otra, ejecútala en el SQL Editor: `update public.clave_producto set clave = 'NUEVA-CLAVE';` (volver a ejecutar `esquema.sql` no la pisa).
> **Si ya habías ejecutado una versión anterior de `esquema.sql`:** vuelve a ejecutar el archivo nuevo completo (agrega la clave y las funciones nuevas, y no borra tus datos).

## Paso 2 — Escribir la conexión en `www/config.js`

Abre `www/config.js` con cualquier editor de texto y llena las dos líneas:

```js
window.VISIONIX_CONFIG = window.VISIONIX_CONFIG || {
  "url": "https://xxxxxxxx.supabase.co",
  "clave": "eyJ… o sb_publishable_…"
};
```

- Hazlo **antes** de generar la APK o publicar la página (se empaqueta con ella). Si cambias de proyecto, se edita ese archivo y se vuelve a empaquetar.
- Si usas el archivo suelto `visionix-prueba-v3.html`, esas mismas líneas están dentro del archivo (busca `VISIONIX_CONFIG` con un editor de texto).
- Sin esta configuración, la aplicación solo muestra un aviso de que no está configurada.

## Paso 3 — Instalar la app

### Opción A (recomendada): generar el APK con GitHub, sin instalar nada en tu computadora

1. Crea una cuenta en <https://github.com> (gratis) y un **repositorio nuevo** (puede ser privado).
2. Sube **todo el contenido de esta carpeta** al repositorio (con `www/config.js` ya lleno).
   - Importante: debe subirse también la carpeta oculta **`.github`** (ahí está el "robot" que compila la app).
     En Mac se ven los archivos ocultos con `Cmd + Shift + .`; en Windows, en el Explorador: Ver → Mostrar → Elementos ocultos.
   - Lo más cómodo: instalar **GitHub Desktop** y arrastrar la carpeta, o usar `git` desde la terminal.
3. En el repositorio, abre la pestaña **Actions**. Si pide habilitarlas, acepta.
4. Elige **«Construir APK de Android»** → **Run workflow**. (También se ejecuta solo cada vez que subes cambios.)
5. Espera unos 5–10 minutos. Cuando aparezca la palomita verde, entra a esa ejecución y, abajo en **Artifacts**, descarga **`visionix-apk`** (es un ZIP que contiene `app-debug.apk`).
6. Pasa `app-debug.apk` al celular (cable, Drive, WhatsApp a ti mismo, etc.) y ábrelo.
   Android pedirá permitir *«instalar apps de orígenes desconocidos»* para la app que usaste para abrirlo; acéptalo.
   Si Play Protect avisa que no reconoce la app, elige **«Instalar de todos modos»** (es normal: es una app de prueba firmada con llave de depuración).
7. Abre **VISIONIX** y acepta el permiso de **cámara**.

**Si el paso 5 muestra una X roja:** entra a la ejecución, abre el paso que falló (marcado en rojo) y copia las últimas líneas del error.

### Opción B: instalarla desde Chrome como página-app (sin APK)

La cámara solo funciona con HTTPS, y GitHub Pages lo da gratis.

1. En el repositorio: **Settings → Pages → Source: GitHub Actions**.
   (En cuentas gratuitas, Pages solo funciona con repositorios *públicos*. El repositorio contendrá la URL y la clave **pública** de tu proyecto —está bien, ver paso 1.4— pero ningún dato de la escuela: esos viven en Supabase.)
2. **Actions → «Publicar como página web instalable (opcional)» → Run workflow.**
3. Abre la dirección que aparece (algo como `https://tu-usuario.github.io/tu-repo/`) en Chrome del celular → menú ⋮ → **«Instalar app»** (o «Añadir a pantalla de inicio»).
   En iPhone: Safari → Compartir → «Añadir a pantalla de inicio» (no lo probé en iPhone).

Después de abrirla una vez con internet, la aplicación y los modelos de reconocimiento quedan guardados en el dispositivo y se abren más rápido (los datos de la escuela siempre vienen de Supabase).

### Opción C: compilar en tu computadora con Android Studio

Necesitas **Node 22** (sirve 20 o superior), **JDK 21** y **Android Studio** (con el SDK de Android 35).

```bash
npm install
npm run vendor                       # copia face-api (reconocimiento facial), sus modelos y supabase-js dentro de www/ (funciona sin internet)
npx cap add android
python3 scripts/permisos_android.py  # agrega el permiso de cámara
npx capacitor-assets generate --android   # (opcional) pone el logo de VISIONIX como icono de la app
npx cap sync android
npx cap open android                 # en Android Studio: conecta tu teléfono con «Depuración USB» y pulsa ▶ Run
```

### Opción D: el archivo suelto `visionix-prueba-v3.html`

Sirve para probar en una computadora: ábrelo con Chrome. La cámara no funciona desde un archivo (usa el **Simulador** del Monitor), y la primera vez necesita internet para descargar la librería de Supabase.

---

## Cómo entrar: administradores y personal autorizado

La app **no trae ninguna cuenta ni contraseña de prueba**. La pantalla de inicio tiene dos pestañas:

- **Personal autorizado** (la que se ve al abrir la app): nombre + puesto + código. Es lo único que ve un profesor que la descarga: **nunca se le pide crear una cuenta**.
- **Administrador:** correo y contraseña. Ahí mismo, debajo, está **«Crear cuenta de administrador»**: pide tu nombre, cargo (opcional), correo, una contraseña que elijas (mínimo 6 caracteres) y la **clave de producto**. Sin la clave correcta no se crea la cuenta (la comprueba la base de datos, no solo la pantalla). Si el sistema está vacío, el Monitor ofrece **«Cargar datos de muestra»** (45 alumnos, 15 grupos, personal, zonas, cámaras y horarios de ejemplo).

La clave de producto sirve para crear **varias** cuentas de administrador (por ejemplo, directora y subdirector). Después, un administrador también puede crear más desde «Personal y grupos → Agregar administrador».
⚠ Quien tenga la clave puede crear una cuenta que **ve y cambia todo**: es de prueba, no la repartas. La base de datos bloquea 5 minutos tras 5 claves equivocadas seguidas (en total, de cualquier persona), para que no se pueda adivinar probando.

Hay dos tipos de cuenta:

| | **Administrador** (directivos) | **Personal autorizado** |
|---|---|---|
| Cómo entra | **Correo** + **contraseña** (la que tú creaste; la maneja Supabase) | Nombre + **puesto** + **código de acceso** (nada más) |
| Puestos | — | Maestro/a, Secretario/a, Tutor/a, Orientador/a |
| Quién da el acceso | Cada administrador crea la suya; otro administrador puede agregar cuentas nuevas | Un administrador: el código se genera solo y **solo se ve dentro de una sesión de administrador**, en «Personal y grupos» |
| Qué puede hacer | Todo: alumnos y **registro de rostros**, zonas y cámaras, horarios, personal y accesos, asistencia, ajustes. Recibe **todas** las notificaciones | **Solo ver sus notificaciones** (y marcarlas como leídas). No registra rostros ni cambia nada |
| Qué avisos recibe | Todos | Solo los de su área (ver abajo) |

**Códigos del personal autorizado**
- Se generan **automáticamente** (6 símbolos, por ejemplo `K7M-4QX`) para cada persona, incluidas las que agregues después.
- La pantalla de inicio **no muestra ningún código ni contraseña**. Solo se ven al entrar como administrador, en «Personal y grupos» (botón «Copiar acceso» para mandárselo a la persona).
- «Regenerar» crea un código nuevo; el anterior deja de servir y la sesión abierta de esa persona se cierra sola (en unos segundos).
- Al escribir el nombre no importan mayúsculas, acentos ni el título («Prof.», «Lic.»…). El código se puede escribir con o sin guion.

**Área del personal autorizado**
- **Maestro/a:** los alumnos del grupo al que da clase en ese momento (según «Horarios»).
- **Tutor/a, secretario/a, orientador/a:** los grupos y zonas que un administrador le asigne con «Elegir áreas». Recibe lo que ocurra en esas zonas y lo que le pase a los alumnos de esos grupos.
- De muestra hay una tutora de 1°1, una secretaria con Patio y Pasillo planta baja, y un orientador de 1°2 y 1°3.

**Personas sin registro facial: avisos discretos y llamativos**
- **Llamativo** (ventana emergente roja e insignia con el número de pendientes): solo cuando una persona sin rostro registrado aparece en una **zona restringida**, **fuera del horario de clase** o en **fin de semana**.
- **Discreto** (cualquier otra zona —salón, patio, pasillos…— durante el horario de clase): una línea gris y compacta en la bandeja, **sin ventana emergente y sin insignia**. No se repite en la misma zona antes de 10 minutos.
- El **horario de clase** de un día va desde 15 minutos antes de la primera clase (o la hora de entrada de una zona común, si es más temprano) hasta el fin de la última clase (o la hora de salida de una zona común, si es más tarde); los recesos cuentan como horario de clase. Un día sin clases programadas también cuenta como fuera de horario. Los días de clase se definen en la configuración (por defecto, lunes a viernes).
- Lo reciben los administradores y el personal que tenga esa zona asignada (los maestros no).
- En Ajustes puedes apagar los avisos discretos o cambiar los minutos entre avisos. Los llamativos no se pueden apagar.

**Seguridad de los accesos** (lo que hace y lo que no):
- Los permisos los hace cumplir **la base de datos** (seguridad por fila), no solo la pantalla: el personal autorizado recibe únicamente lo necesario para ver **sus** avisos (no ve huellas faciales, ni la lista de alumnos, ni los códigos de otras personas) y no puede escribir nada, salvo marcar como leídos sus propios avisos. El administrador ve y cambia todo.
- Las contraseñas de los administradores las guarda Supabase (nunca están en las tablas de VISIONIX). El código del personal es aleatorio; tras varios intentos fallidos con el mismo nombre se bloquea.
- Regenerar o borrar el código de una persona **cierra su sesión abierta**. Un administrador no puede borrar su propia cuenta ni al último administrador. Cada administrador cambia su propia contraseña desde su sesión.
- Solo se guardan **huellas faciales** (números); las fotos del registro no se suben nunca. La miniatura opcional del alumno **no** se sube salvo que lo actives en Ajustes («Enviar también esa miniatura a la nube»).
- ⚠ Es un prototipo y esta seguridad **no ha sido auditada**.

**Contraseña de administrador olvidada**
- Otro administrador no puede cambiarla por ti, y la app no tiene «recuperar por correo». Desde el **SQL Editor** de tu proyecto (sin probar con un Supabase real):
  ```sql
  update auth.users
     set encrypted_password = extensions.crypt('NuevaContraseña', extensions.gen_salt('bf'))
   where email = 'correo-del-administrador@escuela.mx';
  ```
  (si falla `extensions.crypt`, prueba `crypt(...)` / `gen_salt(...)` sin el prefijo).

## Cómo probarla en el teléfono

1. Crea tu cuenta de **administrador** (pestaña Administrador → «Crear cuenta de administrador», con la clave de producto) o entra con ella. Si el sistema está vacío, pulsa «Cargar datos de muestra».
2. **Alumnos → Agregar alumno** (o «Registrar rostro» en uno de muestra): pon tu nombre y mira la cámara.
   Por defecto se usa la cámara frontal; en **Monitor** hay un selector para cambiar a la trasera.
3. **Ajustes → Hora de prueba**: elige una hora que coincida con una clase (por ejemplo «Clase 1 · 07:03»). Es un ajuste compartido: todos los dispositivos lo ven igual.
4. **Monitor**: elige «Cámara Salón 1°1» y pulsa «Iniciar cámara». Al reconocerte se marca tu asistencia (una vez al día).
   Cambia a «Cámara Azotea» (restringida) o «Cámara Patio» (común, fuera de horario) para generar avisos.
5. **Probar que los avisos llegan al mismo tiempo:** abre VISIONIX en un **segundo dispositivo** (o en una ventana de incógnito) y entra como personal autorizado (por ejemplo la secretaria de muestra: nombre, puesto y código de «Personal y grupos»).
   En el primer dispositivo usa el **Simulador** del Monitor («Persona no identificada», una cámara, «Simular detección»): el aviso aparece solo en el otro, sin recargar. Arriba verás «☁ En línea · 2 dispositivos».
   La sesión se guarda en el navegador: para dos roles en la misma computadora usa otro navegador o incógnito.

## Cosas que conviene saber

- **Sin internet:** con la sesión ya abierta, la app sigue trabajando y reenvía sus cambios al volver (aparece «Sin conexión · se reenviará al volver»; si cierras la app antes, se pierde lo pendiente). Pero **no guarda los datos de la escuela en el dispositivo**: sin internet no se puede abrir una sesión nueva ni consultar datos.
- Si dos personas editan **exactamente la misma configuración** a la vez, queda la última que llegó. Los avisos y asistencias nuevos se conservan siempre.
- **«Restablecer datos de muestra» e «Importar respaldo» cambian los datos de TODA la escuela**, no solo los de ese dispositivo (los administradores se conservan). Úsalos con cuidado.
- **Los datos de la escuela son datos de menores.** Revisa la región de tu proyecto, quién tiene acceso al panel de Supabase y activa su verificación en dos pasos. Para uso real hacen falta aviso de privacidad y consentimientos.
- **Plan gratuito de Supabase:** los proyectos gratuitos pueden pausarse por inactividad y tienen límites de tamaño (revisa las condiciones vigentes). Para una escuela real conviene un plan de pago y copias de seguridad.
- **Limpieza opcional:** cada vez que el personal entra desde un dispositivo nuevo, Supabase crea un usuario anónimo. Con el tiempo se acumulan; el final de `esquema.sql` trae (comentado) un comando para borrar los que llevan 30 días sin usarse.
- **Datos de versiones anteriores:** si antes probaste una versión que guardaba todo en el teléfono o navegador, esos datos (incluidas huellas faciales) siguen ahí, aunque la app ya no los usa. Para borrarlos: Ajustes del teléfono → Apps → VISIONIX → Almacenamiento → Borrar datos (o borra los datos del sitio en el navegador).

### Si algo no funciona: mensajes y qué significan

Por diseño la app **no explica pasos de Supabase en pantalla**; estos son los mensajes y su causa. El detalle técnico está en la consola del navegador (F12 → Consola).

| Mensaje | Causa y arreglo |
|---|---|
| «La aplicación no está configurada para conectarse a su servidor» | `config.js` vacío o inválido (clave secreta, URL sin `https`). Revisa el paso 2. |
| «La base de datos del servidor no está lista» | No se ejecutó `supabase/esquema.sql` (paso 1.2). Si acabas de ejecutarlo, espera un minuto: Supabase actualiza su caché. |
| «Ese correo aún no está confirmado» / «La cuenta se creó, pero el servidor exige confirmar el correo antes de entrar» | «Confirm email» está activo (paso 1.3). Desactívalo; la cuenta que quedó sin confirmar bórrala en Authentication → Users (o repite el formulario con el mismo correo y contraseña). |
| «La clave de producto no es correcta» | Revisa la clave (en la versión de prueba es `V15I0N1X`; no importan mayúsculas) o si la cambiaste con `update public.clave_producto …`. |
| «Demasiados intentos. Espera N min…» | 5 claves de producto equivocadas seguidas: se bloquea unos minutos. |
| «Ya existe una cuenta con ese correo…» / «Esa cuenta ya existe: usa «Iniciar sesión»» | Ese correo ya tiene cuenta; entra con su contraseña por «Administrador → Iniciar sesión». |
| «El servidor no permite el acceso del personal autorizado» | «Allow anonymous sign-ins» está desactivado (paso 1.3). |
| «El servidor no permite crear cuentas nuevas» | «Allow new users to sign up» está desactivado (paso 1.3). |
| «La aplicación no se pudo identificar ante el servidor» | URL o clave incorrectas en `config.js` (paso 1.4 / 2). |
| «No se pudo cargar un componente necesario de la aplicación» | No se pudo descargar la librería de Supabase. En la APK y en la página publicada viene incluida (`npm run vendor`); en el archivo suelto necesita internet la primera vez. |
| «Sin conexión con el servidor» | Sin internet o proyecto pausado. |

## Limitaciones conocidas (leer antes de probar)

- **Sin probar con un Supabase real ni en un teléfono real:** la conexión con un proyecto real de Supabase (su librería, autenticación, Realtime y los menús del panel), la compilación del APK, la instalación, el permiso de cámara de Android y el reconocimiento facial *real*.
  En mis pruebas el reconocimiento estaba simulado; los modelos reales de face-api sí se usan en tu teléfono, pero su precisión (luz, ángulo, distancia, velocidad del teléfono) hay que comprobarla en la práctica.
- **Solo funciona con la app abierta y la pantalla encendida.** Android detiene la cámara de las apps en segundo plano, así que no vigila mientras está bloqueado el teléfono. Para vigilar de verdad se necesita otra arquitectura (cámaras IP + servidor), como platicamos.
- **No hay notificaciones del sistema** (las que suenan con la app cerrada): los avisos llegan en tiempo real, pero **a la app abierta** (mensaje emergente y bandeja). Para avisos con la app cerrada haría falta agregar notificaciones push (Firebase) y una función en el servidor; no está hecho.
- **Respaldo:** en la app instalada no se pueden descargar archivos, así que «Exportar respaldo» muestra el texto para **copiarlo** (pégalo en notas o correo) y «Importar pegando texto» lo restaura. El respaldo incluye las huellas faciales: guárdalo con cuidado. Los respaldos de versiones anteriores a la 3 no se pueden importar.
- **El APK es de depuración:** sirve para probar y compartir con quien tú quieras, pero no se puede subir a Google Play sin firmarlo para publicación.
- **Privacidad:** las huellas faciales son datos biométricos. Para esta prueba usa **solo tu propio rostro** o el de personas que den su consentimiento;
  no registres a alumnos reales (menores) sin autorización de la escuela, de los tutores y sin cumplir la normativa de protección de datos que aplique.
- Versiones usadas: Capacitor 7, Node 22, JDK 21, Android SDK 35. Si en el futuro GitHub cambia sus equipos de compilación, puede hacer falta actualizar el archivo `.github/workflows/android-apk.yml`.

## Qué hay en esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `www/index.html` | La app completa (inicio de sesión y permisos, reglas de zonas/horarios/asistencia, reconocimiento facial y conexión con Supabase) |
| `www/config.js` | **La conexión a tu proyecto de Supabase** (URL y clave pública). Se llena una sola vez (paso 2) |
| `supabase/esquema.sql` | Crea en tu proyecto de Supabase las tablas, los permisos por fila y las funciones de acceso (se pega en el SQL Editor) |
| `www/manifest.webmanifest`, `www/sw.js`, `www/icons/` | Hacen que se pueda instalar como página-app |
| `package.json`, `capacitor.config.json` | Empaquetado como app Android con Capacitor (id: `com.visionix.prueba`) |
| `scripts/copiar_libreria.js` | Copia las librerías (reconocimiento facial y su modelo, y `supabase-js`) dentro de la app |
| `scripts/permisos_android.py` | Agrega el permiso de cámara al proyecto Android |
| `assets/` | Ícono de la app con el logo de VISIONIX (se aplica con `capacitor-assets`; el logo completo va dentro de la pantalla de inicio de sesión) |
| `.github/workflows/android-apk.yml` | Compila el APK automáticamente en GitHub |
| `.github/workflows/pages.yml` | (Opcional) Publica la página instalable en GitHub Pages |
