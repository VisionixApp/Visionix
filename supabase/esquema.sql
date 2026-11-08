-- ============================================================================
-- VISIONIX · base de datos para Supabase
--
-- Cómo usarlo: en tu proyecto NUEVO de Supabase abre «SQL Editor», pega TODO este
-- archivo y pulsa «Run». Se puede ejecutar más de una vez sin romper nada.
-- Después sigue los pasos del README (Authentication → ajustes, y copiar la URL y
-- la clave «anon» del proyecto dentro de VISIONIX).
--
-- Qué crea
--   · Una tabla por cada lista de la app (grupos, zonas, cámaras, horarios,
--     alumnos, asistencias, notificaciones, usuarios, ajustes). Cada fila guarda
--     el elemento completo en «data» (jsonb) y su posición en «orden».
--   · «perfiles»: quién es administrador y quién es personal autorizado.
--   · Seguridad por fila (RLS): el ADMINISTRADOR lo ve y lo cambia todo; el
--     PERSONAL AUTORIZADO solo lee lo que necesita para ver SUS avisos y no puede
--     escribir nada (solo marcar como leídos sus avisos, con una función).
--   · Funciones para entrar: verificar_clave_producto y crear_admin_con_clave
--     (crear una cuenta de administrador exige la CLAVE DE PRODUCTO), registrar_admin,
--     entrar_personal (con bloqueo tras varios intentos), salir_personal,
--     marcar_leidas.
--   · «clave_producto»: la clave que pide la app para crear cuentas de administrador
--     (en esta versión de prueba es V15I0N1X; cómo cambiarla: al final de este archivo).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tablas
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['grupos','zonas','camaras','horarios','alumnos','asistencias','notificaciones','ajustes'] loop
    execute format(
      'create table if not exists public.%I (id text primary key, data jsonb not null, updated_at timestamptz not null default now(), orden bigint not null default 0)', t);
  end loop;
end $$;

-- Usuarios: además del elemento completo, tres columnas para poder comprobar el acceso del personal sin exponer nada.
create table if not exists public.usuarios (
  id          text primary key,
  data        jsonb not null,
  updated_at  timestamptz not null default now(),
  orden       bigint not null default 0,   -- para mostrar las listas en el mismo orden en todos los dispositivos
  nombre_norm text not null default '',   -- nombre sin mayúsculas, acentos ni títulos
  puesto      text not null default '',   -- maestro, secretaria, tutor, orientador o directivo
  codigo_norm text not null default ''    -- código de acceso sin guion (solo personal autorizado)
);

-- Quién es quién en la nube. Solo las funciones de abajo escriben aquí.
create table if not exists public.perfiles (
  auth_uid   uuid primary key references auth.users (id) on delete cascade,
  rol        text not null check (rol in ('admin', 'personal')),
  persona_id text not null,
  creado     timestamptz not null default now()
);
create index if not exists perfiles_persona_idx on public.perfiles (persona_id);

-- Intentos fallidos de entrada del personal (para bloquear adivinanzas de códigos).
create table if not exists public.intentos_login (
  clave  text primary key,
  n      integer not null default 0,
  hasta  timestamptz,
  ultimo timestamptz not null default now()
);

-- Clave de producto: la que hay que escribir para crear una cuenta de administrador (una sola fila).
-- Nadie la lee ni la cambia desde la app (sin permisos ni políticas): solo las funciones de abajo.
-- Al volver a ejecutar este archivo NO se pisa una clave que ya hayas cambiado.
create table if not exists public.clave_producto (
  id    integer primary key default 1 check (id = 1),
  clave text not null
);
insert into public.clave_producto (id, clave) values (1, 'V15I0N1X') on conflict (id) do nothing;

-- «updated_at» siempre al día
create or replace function public.tocar_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Funciones de apoyo para los permisos
-- ---------------------------------------------------------------------------
create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfiles where auth_uid = auth.uid() and rol = 'admin')
$$;

create or replace function public.es_personal() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfiles where auth_uid = auth.uid() and rol = 'personal')
$$;

-- id de la persona (fila de «usuarios») de la sesión actual, sea admin o personal
create or replace function public.mi_persona() returns text
language sql stable security definer set search_path = public as $$
  select persona_id from public.perfiles where auth_uid = auth.uid()
$$;

-- Las sesiones «anónimas» (las del personal antes de entrar) nunca pueden ser administradoras.
create or replace function public.soy_anonimo() returns boolean
language sql stable as $$
  select coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false)
$$;

-- ---------------------------------------------------------------------------
-- 3. Seguridad por fila (RLS)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['grupos','zonas','camaras','horarios','alumnos','asistencias','notificaciones','ajustes','usuarios'] loop
    execute format('alter table public.%I enable row level security', t);
    -- el administrador lo puede todo
    execute format('drop policy if exists admin_todo on public.%I', t);
    execute format('create policy admin_todo on public.%I for all to authenticated using (public.es_admin()) with check (public.es_admin())', t);
    execute format('drop trigger if exists tocar on public.%I', t);
    execute format('create trigger tocar before insert or update on public.%I for each row execute function public.tocar_updated_at()', t);
  end loop;
end $$;

-- El personal autorizado SOLO LEE (y solo esto):
--   grupos, zonas, cámaras y ajustes: para mostrar nombres en sus avisos
drop policy if exists personal_lee on public.grupos;
create policy personal_lee on public.grupos for select to authenticated using (public.es_personal());
drop policy if exists personal_lee on public.zonas;
create policy personal_lee on public.zonas for select to authenticated using (public.es_personal());
drop policy if exists personal_lee on public.camaras;
create policy personal_lee on public.camaras for select to authenticated using (public.es_personal());
drop policy if exists personal_lee on public.ajustes;
create policy personal_lee on public.ajustes for select to authenticated using (public.es_personal());
--   horarios: solo las clases que da esa persona (para saber a qué grupo da clase ahora)
drop policy if exists personal_lee on public.horarios;
create policy personal_lee on public.horarios for select to authenticated
  using (public.es_personal() and data ->> 'docenteId' = public.mi_persona());
--   usuarios: solo su propia fila
drop policy if exists personal_lee on public.usuarios;
create policy personal_lee on public.usuarios for select to authenticated
  using (public.es_personal() and id = public.mi_persona());
--   notificaciones: solo las dirigidas a esa persona
drop policy if exists personal_lee on public.notificaciones;
create policy personal_lee on public.notificaciones for select to authenticated
  using (public.es_personal() and (data -> 'destinatarios') ? public.mi_persona());
-- alumnos (con sus huellas faciales) y asistencias: SOLO administradores (no hay política para el personal).

alter table public.perfiles enable row level security;
drop policy if exists ver_el_mio on public.perfiles;
create policy ver_el_mio on public.perfiles for select to authenticated using (auth_uid = auth.uid());

alter table public.intentos_login enable row level security;  -- sin políticas: nadie la toca directamente
alter table public.clave_producto enable row level security;  -- ídem

-- Permisos de tabla: nada para «anon»; «authenticated» solo lo que las políticas permitan.
revoke all on all tables in schema public from anon, authenticated;
grant select, insert, update, delete on
  public.grupos, public.zonas, public.camaras, public.horarios, public.alumnos,
  public.asistencias, public.notificaciones, public.ajustes, public.usuarios
  to authenticated;
grant select on public.perfiles to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Al cambiar o borrar a una persona se cierran sus accesos
-- ---------------------------------------------------------------------------
create or replace function public.usuarios_revocar() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from public.perfiles where persona_id = old.id and rol = 'admin')
       and (select count(*) from public.perfiles where rol = 'admin') <= 1 then
      raise exception 'Debe quedar al menos un administrador.';
    end if;
    delete from public.perfiles where persona_id = old.id;
    return old;
  end if;
  -- código nuevo => el anterior deja de valer y las sesiones abiertas con él pierden el acceso
  if new.codigo_norm is distinct from old.codigo_norm then
    delete from public.perfiles where persona_id = old.id and rol = 'personal';
  end if;
  return new;
end $$;
drop trigger if exists revocar on public.usuarios;
create trigger revocar after update or delete on public.usuarios
  for each row execute function public.usuarios_revocar();

-- ---------------------------------------------------------------------------
-- 5. Funciones que usa la app para entrar
-- ---------------------------------------------------------------------------

-- ¿Ya existe algún administrador? (la app lo pregunta antes de iniciar sesión)
create or replace function public.hay_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfiles where rol = 'admin')
$$;

-- ¿Es correcta la clave de producto? (la app lo pregunta ANTES de crear la cuenta, para no dejar cuentas a medias)
-- Tras 5 fallos seguidos (en total, de cualquier persona) se bloquea 5 minutos: así no se puede adivinar probando.
-- Importante: devuelve el fallo en lugar de lanzar un error, para que el contador de intentos no se deshaga.
drop function if exists public.crear_primer_admin(text, text, text);          -- versiones anteriores
drop function if exists public.crear_primer_admin_manual(text, text, text);
create or replace function public.verificar_clave_producto(p_clave text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_claves text[] := array['k:global'];
  v_k text;
  v_hasta timestamptz;
  v_n integer;
begin
  if v_uid is not null then v_claves := v_claves || ('k:' || v_uid::text); end if;
  select max(hasta) into v_hasta from public.intentos_login where clave = any (v_claves) and hasta > now();
  if v_hasta is not null then
    return jsonb_build_object('ok', false, 'motivo', 'bloqueado', 'espera', ceil(extract(epoch from (v_hasta - now())))::integer);
  end if;
  if coalesce(trim(p_clave), '') <> ''
     and upper(regexp_replace(p_clave, '\s', '', 'g')) = (select upper(clave) from public.clave_producto where id = 1) then
    if v_uid is not null then delete from public.intentos_login where clave = 'k:' || v_uid::text; end if;
    return jsonb_build_object('ok', true);
  end if;
  foreach v_k in array v_claves loop
    insert into public.intentos_login (clave, n, ultimo) values (v_k, 1, now())
      on conflict (clave) do update
        set n = case when public.intentos_login.ultimo < now() - interval '15 minutes' then 1 else public.intentos_login.n + 1 end,
            ultimo = now()
      returning n into v_n;
    if v_n >= 5 then
      update public.intentos_login set hasta = now() + interval '5 minutes', n = 0 where clave = v_k;
    end if;
  end loop;
  return jsonb_build_object('ok', false, 'motivo', 'clave');
end $$;

-- Crea una cuenta de administrador para quien ya tiene su cuenta con correo y contraseña (la app la crea con auth.signUp),
-- siempre que escriba la clave de producto correcta. Devuelve {ok:true, usuario} o {ok:false, motivo, espera}.
create or replace function public.crear_admin_con_clave(p_id text, p_nombre text, p_detalle text, p_clave text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_v jsonb; v_email text; v_data jsonb;
begin
  if v_uid is null or public.soy_anonimo() then
    raise exception 'Necesitas una cuenta con correo y contraseña.';
  end if;
  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_id), '') = '' then raise exception 'Falta el nombre.'; end if;
  if exists (select 1 from public.perfiles where auth_uid = v_uid) then raise exception 'Esta cuenta ya tiene un perfil.'; end if;
  v_v := public.verificar_clave_producto(p_clave);
  if not coalesce((v_v ->> 'ok')::boolean, false) then return v_v; end if;
  select email into v_email from auth.users where id = v_uid;
  v_data := jsonb_build_object('id', p_id, 'nombre', trim(p_nombre), 'detalle', coalesce(trim(p_detalle), ''), 'rol', 'directivo', 'email', v_email);
  insert into public.usuarios (id, data, nombre_norm, puesto, codigo_norm)
    values (p_id, v_data, lower(trim(p_nombre)), 'directivo', '');
  insert into public.perfiles (auth_uid, rol, persona_id) values (v_uid, 'admin', p_id);
  return jsonb_build_object('ok', true, 'usuario', v_data);
end $$;

-- Un administrador da de alta a otro (la cuenta con correo ya se creó con auth.signUp).
create or replace function public.registrar_admin(p_auth_uid uuid, p_id text, p_nombre text, p_detalle text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_email text; v_anon boolean; v_data jsonb;
begin
  if not public.es_admin() then raise exception 'Solo un administrador puede hacer esto.'; end if;
  select email, coalesce(is_anonymous, false) into v_email, v_anon from auth.users where id = p_auth_uid;
  if not found or v_anon or v_email is null then raise exception 'Esa cuenta no existe o no tiene correo.'; end if;
  if exists (select 1 from public.perfiles where auth_uid = p_auth_uid) then raise exception 'Esa cuenta ya tiene un perfil.'; end if;
  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_id), '') = '' then raise exception 'Falta el nombre.'; end if;
  v_data := jsonb_build_object('id', p_id, 'nombre', trim(p_nombre), 'detalle', coalesce(trim(p_detalle), ''), 'rol', 'directivo', 'email', v_email);
  insert into public.usuarios (id, data, nombre_norm, puesto, codigo_norm)
    values (p_id, v_data, lower(trim(p_nombre)), 'directivo', '');
  insert into public.perfiles (auth_uid, rol, persona_id) values (p_auth_uid, 'admin', p_id);
  return v_data;
end $$;

-- Entrada del personal autorizado: nombre + puesto + código. Devuelve {ok:true,id} o {ok:false,motivo,espera}.
-- Tras 5 fallos seguidos con el mismo nombre (o desde la misma sesión) se bloquea 5 minutos.
-- Importante: devuelve el fallo en lugar de lanzar un error, para que el contador de intentos no se deshaga.
create or replace function public.entrar_personal(p_nombre_norm text, p_puesto text, p_codigo_norm text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_claves text[];
  v_k text;
  v_hasta timestamptz;
  v_u public.usuarios%rowtype;
  v_n integer;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'motivo', 'sin_sesion'); end if;
  if public.es_admin() then return jsonb_build_object('ok', false, 'motivo', 'es_admin'); end if;
  v_claves := array['n:' || left(coalesce(p_nombre_norm, ''), 80), 'u:' || v_uid::text];

  select max(hasta) into v_hasta from public.intentos_login where clave = any (v_claves) and hasta > now();
  if v_hasta is not null then
    return jsonb_build_object('ok', false, 'motivo', 'bloqueado', 'espera', ceil(extract(epoch from (v_hasta - now())))::integer);
  end if;

  if coalesce(p_nombre_norm, '') <> '' and coalesce(p_codigo_norm, '') <> '' and p_puesto <> 'directivo' then
    select * into v_u from public.usuarios
      where nombre_norm = p_nombre_norm and puesto = p_puesto and codigo_norm = p_codigo_norm limit 1;
  end if;

  if v_u.id is not null then
    delete from public.intentos_login where clave = any (v_claves);
    insert into public.perfiles (auth_uid, rol, persona_id) values (v_uid, 'personal', v_u.id)
      on conflict (auth_uid) do update set persona_id = excluded.persona_id, rol = 'personal';
    return jsonb_build_object('ok', true, 'id', v_u.id);
  end if;

  foreach v_k in array v_claves loop
    insert into public.intentos_login (clave, n, ultimo) values (v_k, 1, now())
      on conflict (clave) do update
        set n = case when public.intentos_login.ultimo < now() - interval '15 minutes' then 1 else public.intentos_login.n + 1 end,
            ultimo = now()
      returning n into v_n;
    if v_n >= 5 then
      update public.intentos_login set hasta = now() + interval '5 minutes', n = 0 where clave = v_k;
    end if;
  end loop;
  return jsonb_build_object('ok', false, 'motivo', 'credenciales');
end $$;

-- Cerrar la sesión del personal: se retira el permiso a esa sesión.
create or replace function public.salir_personal() returns void
language sql security definer set search_path = public as $$
  delete from public.perfiles where auth_uid = auth.uid() and rol = 'personal'
$$;

-- Marcar avisos como leídos. El personal solo puede con los suyos; el administrador, con cualquiera.
-- (Se hace con una función para que dos personas marcando a la vez no se pisen.)
create or replace function public.marcar_leidas(p_ids text[]) returns integer
language plpgsql security definer set search_path = public as $$
declare v_yo text := public.mi_persona(); v_n integer;
begin
  if v_yo is null then return 0; end if;
  update public.notificaciones n
     set data = jsonb_set(n.data, '{leidaPor}',
           (select coalesce(jsonb_agg(distinct x), '[]'::jsonb)
              from jsonb_array_elements_text(coalesce(n.data -> 'leidaPor', '[]'::jsonb) || to_jsonb(v_yo)) x))
   where n.id = any (p_ids)
     and (public.es_admin() or (n.data -> 'destinatarios') ? v_yo);
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- Quién puede llamar a qué
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.hay_admin() to anon, authenticated;
grant execute on function public.es_admin(), public.es_personal(), public.mi_persona() to authenticated;
grant execute on function public.verificar_clave_producto(text) to anon, authenticated;
grant execute on function public.crear_admin_con_clave(text, text, text, text) to authenticated;
grant execute on function public.registrar_admin(uuid, text, text, text) to authenticated;
grant execute on function public.entrar_personal(text, text, text) to authenticated;
grant execute on function public.salir_personal() to authenticated;
grant execute on function public.marcar_leidas(text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Tiempo real: avisar a los dispositivos conectados cuando cambia una tabla
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime' and not puballtables) then
    foreach t in array array['grupos','zonas','camaras','horarios','alumnos','asistencias','notificaciones','ajustes','usuarios'] loop
      if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Opcional (limpieza): borra las sesiones anónimas con más de 30 días sin usarse.
--   delete from auth.users where is_anonymous and coalesce(last_sign_in_at, created_at) < now() - interval '30 days';
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- CLAVE DE PRODUCTO (para crear cuentas de administrador en la app)
--   En esta versión de prueba es  V15I0N1X  (la app la muestra como comentario de prueba en esa pantalla).
--   Para cambiarla, ejecuta (con la clave que quieras):
--
--        update public.clave_producto set clave = 'NUEVA-CLAVE';
--
--   Quien tenga la clave puede crear cuentas de administrador (ven y cambian TODO): no la repartas.
-- ---------------------------------------------------------------------------
