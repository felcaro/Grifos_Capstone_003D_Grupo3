-- =====================================================================
-- Esquema de base de datos: Bomberos / Grifos (PostgreSQL + PostGIS)
-- Compatible con Supabase. Generado a partir de los CSV exportados.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

-- ---------------------------------------------------------------------
-- 1. SECTOR
-- ---------------------------------------------------------------------
CREATE TABLE sector (
    id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre  text NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- 2. COMPAÑÍA DE BOMBEROS
-- ---------------------------------------------------------------------
CREATE TABLE compania_bomberos (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre     text NOT NULL,
    comuna     text,
    sector_id  uuid REFERENCES sector(id) ON UPDATE CASCADE ON DELETE SET NULL
);
CREATE INDEX idx_compania_sector ON compania_bomberos(sector_id);

-- ---------------------------------------------------------------------
-- 3. USUARIO
-- (En Supabase, si usas auth, puedes agregar:
--  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE)
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compania_id        uuid REFERENCES compania_bomberos(id) ON UPDATE CASCADE ON DELETE SET NULL,
    credencial         text NOT NULL UNIQUE,          -- correo o código (ej. CB-TEST1)
    nombre             text NOT NULL,
    rol                text NOT NULL DEFAULT 'pendiente',
    numero_voluntario  integer,
    numero_maquinista  integer,
    created_at         timestamptz NOT NULL DEFAULT now(),
    -- Los datos actuales mezclan mayúsculas/minúsculas, por eso se compara en lower()
    CONSTRAINT chk_usuario_rol CHECK (
        lower(rol) IN ('pendiente', 'bombero', 'bombero_voluntario',
                       'tesorero', 'administrador')
    )
);
CREATE INDEX idx_usuario_compania ON usuario(compania_id);

-- ---------------------------------------------------------------------
-- 4. GRIFO
-- ---------------------------------------------------------------------
CREATE TABLE grifo (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    sector_id              uuid REFERENCES sector(id)  ON UPDATE CASCADE ON DELETE SET NULL,
    creado_por             uuid REFERENCES usuario(id) ON UPDATE CASCADE ON DELETE SET NULL,
    latitud                numeric(10,7) NOT NULL,
    longitud               numeric(10,7) NOT NULL,
    ubicacion              geography(Point, 4326),    -- el CSV trae EWKB hex, se importa directo
    direccion_referencial  text,
    estado                 text NOT NULL DEFAULT 'operativo',
    ultima_revision        timestamptz,
    CONSTRAINT chk_grifo_estado CHECK (estado IN ('operativo', 'inhabilitado', 'obstruido', 'con_falla'))
);
CREATE INDEX idx_grifo_sector    ON grifo(sector_id);
CREATE INDEX idx_grifo_estado    ON grifo(estado);
CREATE INDEX idx_grifo_ubicacion ON grifo USING gist(ubicacion);

-- ---------------------------------------------------------------------
-- 5. REPORTE DE FALLA
-- ---------------------------------------------------------------------
CREATE TABLE reporte_falla (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    grifo_id        uuid NOT NULL REFERENCES grifo(id)   ON UPDATE CASCADE ON DELETE CASCADE,
    usuario_id      uuid REFERENCES usuario(id)          ON UPDATE CASCADE ON DELETE SET NULL,
    tipo_falla      text NOT NULL,
    detalle         text,
    foto_url        text,
    fecha_creacion  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_reporte_tipo CHECK (tipo_falla IN ('operativo', 'inhabilitado', 'obstruido', 'con_falla'))
);
CREATE INDEX idx_reporte_grifo   ON reporte_falla(grifo_id);
CREATE INDEX idx_reporte_usuario ON reporte_falla(usuario_id);

-- ---------------------------------------------------------------------
-- 6. ACTA
-- ---------------------------------------------------------------------
CREATE TABLE acta (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compania_id    uuid NOT NULL REFERENCES compania_bomberos(id) ON UPDATE CASCADE ON DELETE CASCADE,
    creado_por     uuid REFERENCES usuario(id)                    ON UPDATE CASCADE ON DELETE SET NULL,
    titulo         text NOT NULL,
    fecha_reunion  date NOT NULL,
    archivo_url    text
);
CREATE INDEX idx_acta_compania ON acta(compania_id);

-- ---------------------------------------------------------------------
-- 7. CAMPAÑA ECONÓMICA
-- ---------------------------------------------------------------------
CREATE TABLE campana_economica (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compania_id  uuid NOT NULL REFERENCES compania_bomberos(id) ON UPDATE CASCADE ON DELETE CASCADE,
    nombre       text NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin    date,
    CONSTRAINT chk_campana_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);
CREATE INDEX idx_campana_compania ON campana_economica(compania_id);

-- ---------------------------------------------------------------------
-- 8. MOVIMIENTO DE TESORERÍA
-- ---------------------------------------------------------------------
CREATE TABLE movimiento_tesoreria (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compania_id    uuid NOT NULL REFERENCES compania_bomberos(id)  ON UPDATE CASCADE ON DELETE CASCADE,
    campana_id     uuid REFERENCES campana_economica(id)           ON UPDATE CASCADE ON DELETE SET NULL,
    registrado_por uuid REFERENCES usuario(id)                     ON UPDATE CASCADE ON DELETE SET NULL,
    tipo           text NOT NULL,
    monto          numeric(14,2) NOT NULL CHECK (monto >= 0),
    fecha          timestamptz NOT NULL DEFAULT now(),
    boleta_url     text,
    descripcion    text,
    CONSTRAINT chk_movimiento_tipo CHECK (tipo IN ('ingreso', 'egreso'))
);
CREATE INDEX idx_mov_compania ON movimiento_tesoreria(compania_id);
CREATE INDEX idx_mov_campana  ON movimiento_tesoreria(campana_id);
CREATE INDEX idx_mov_fecha    ON movimiento_tesoreria(fecha);

-- ---------------------------------------------------------------------
-- 9. CARRO (vehículo)
-- ---------------------------------------------------------------------
CREATE TABLE carro (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compania_id                uuid NOT NULL REFERENCES compania_bomberos(id) ON UPDATE CASCADE ON DELETE CASCADE,
    nombre                     text NOT NULL,                 -- ej. RH-1
    tipo                       text NOT NULL,                 -- ej. RESCATE
    patente                    text,
    foto_url                   text,
    creado_en                  timestamptz NOT NULL DEFAULT now(),
    revision_tecnica_vence     date,
    permiso_circulacion_vence  date,
    soap_vence                 date,
    mantencion_ultima_fecha    date,
    mantencion_ultimo_km       integer,
    km_actual                  integer,
    mantencion_cada_meses      integer DEFAULT 12,
    mantencion_cada_km         integer DEFAULT 10000,
    UNIQUE (compania_id, nombre)
);
CREATE INDEX idx_carro_compania ON carro(compania_id);

-- ---------------------------------------------------------------------
-- 10. COMPARTIMENTO (de un carro)
-- ---------------------------------------------------------------------
CREATE TABLE compartimento (
    id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    carro_id  uuid NOT NULL REFERENCES carro(id) ON UPDATE CASCADE ON DELETE CASCADE,
    nombre    text NOT NULL,
    orden     integer NOT NULL DEFAULT 0
);
CREATE INDEX idx_compartimento_carro ON compartimento(carro_id);

-- ---------------------------------------------------------------------
-- 11. ÍTEM DE INVENTARIO (dentro de un compartimento)
-- ---------------------------------------------------------------------
CREATE TABLE item_inventario (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compartimento_id  uuid NOT NULL REFERENCES compartimento(id) ON UPDATE CASCADE ON DELETE CASCADE,
    nombre            text NOT NULL,
    cantidad          integer NOT NULL DEFAULT 1 CHECK (cantidad >= 0),
    estado            text NOT NULL DEFAULT 'BUENO',
    observacion       text,
    actualizado_por   uuid REFERENCES usuario(id) ON UPDATE CASCADE ON DELETE SET NULL,
    actualizado_en    timestamptz NOT NULL DEFAULT now(),
    fecha_compra      date,
    vida_util_anios   integer CHECK (vida_util_anios IS NULL OR vida_util_anios > 0)
);
CREATE INDEX idx_item_compartimento ON item_inventario(compartimento_id);

-- ---------------------------------------------------------------------
-- 12. EQUIPO PERSONAL (asignado a un usuario)
-- ---------------------------------------------------------------------
CREATE TABLE equipo_personal (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id       uuid NOT NULL REFERENCES usuario(id) ON UPDATE CASCADE ON DELETE CASCADE,
    categoria        text NOT NULL,                 -- ej. ESTRUCTURAL
    nombre           text NOT NULL,
    detalle          text,
    estado           text NOT NULL DEFAULT 'BUENO',
    fecha_compra     date,
    vida_util_anios  integer CHECK (vida_util_anios IS NULL OR vida_util_anios > 0),
    observacion      text,
    asignado_por     uuid REFERENCES usuario(id) ON UPDATE CASCADE ON DELETE SET NULL,
    actualizado_en   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_equipo_usuario ON equipo_personal(usuario_id);

-- =====================================================================
-- Orden sugerido para importar los CSV (respeta las llaves foráneas):
--   1 sector              7 campana_economica
--   2 compania_bomberos   8 movimiento_tesoreria
--   3 usuario             9 acta
--   4 carro              10 compartimento
--   5 grifo              11 item_inventario
--   6 reporte_falla      12 equipo_personal
-- Nota: sector.nombre y compania_bomberos.comuna traen saltos de línea
-- ("\n") en los datos; conviene limpiarlos con trim() tras importar:
--   UPDATE sector SET nombre = btrim(nombre);
--   UPDATE compania_bomberos SET comuna = btrim(comuna);
-- =====================================================================

-- =====================================================================
-- TABLAS ADICIONALES (tomadas del diagrama de Supabase)
-- Tipos inferidos de la imagen; verifica con el dump real.
-- =====================================================================

-- 13. MANTENCIÓN DE CARRO
CREATE TABLE carro_mantencion (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    carro_id     uuid NOT NULL REFERENCES carro(id)   ON UPDATE CASCADE ON DELETE CASCADE,
    fecha        date NOT NULL,
    km           integer,
    tipo         text NOT NULL,
    taller       text,
    descripcion  text,
    creado_por   uuid REFERENCES usuario(id) ON UPDATE CASCADE ON DELETE SET NULL,
    creado_en    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_carro_mantencion_carro ON carro_mantencion(carro_id);

-- 14. ENTREGA DE APP
CREATE TABLE entrega_app (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    compania_id         uuid NOT NULL REFERENCES compania_bomberos(id) ON UPDATE CASCADE ON DELETE CASCADE,
    voluntario_nombre   text NOT NULL,
    voluntario_run      text NOT NULL,
    n_registro          text NOT NULL,
    fecha               date NOT NULL,
    archivo_url         text NOT NULL,
    creado_por          uuid REFERENCES usuario(id) ON UPDATE CASCADE ON DELETE SET NULL,
    creado_en           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_entrega_app_compania ON entrega_app(compania_id);

-- 15. REGISTRO DE SINCRONIZACIÓN (offline -> servidor)
CREATE TABLE registro_sincronizacion (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id            uuid NOT NULL REFERENCES usuario(id) ON UPDATE CASCADE ON DELETE CASCADE,
    entidad               text NOT NULL,
    entidad_id            uuid NOT NULL,
    estado_subida         text NOT NULL,
    fecha_creacion_local  timestamptz NOT NULL
);
CREATE INDEX idx_regsync_usuario ON registro_sincronizacion(usuario_id);
