--Function to remove accents
CREATE TEMP FUNCTION accent2latin(word STRING) AS
((
  WITH lookups AS (
    SELECT 
    'ç,æ,œ,á,é,í,ó,ú,à,è,ì,ò,ù,ä,ë,ï,ö,ü,ÿ,â,ê,î,ô,û,å,ø,Ø,Å,Á,À,Â,Ä,È,É,Ê,Ë,Í,Î,Ï,Ì,Ò,Ó,Ô,Ö,Ú,Ù,Û,Ü,Ÿ,Ç,Æ,Œ,ñ' AS accents,
    'c,ae,oe,a,e,i,o,u,a,e,i,o,u,a,e,i,o,u,y,a,e,i,o,u,a,o,O,A,A,A,A,A,E,E,E,E,I,I,I,I,O,O,O,O,U,U,U,U,Y,C,AE,OE,n' AS latins
  ),
  pairs AS (
    SELECT accent, latin FROM lookups, 
      UNNEST(SPLIT(accents)) AS accent WITH OFFSET AS p1, 
      UNNEST(SPLIT(latins)) AS latin WITH OFFSET AS p2
    WHERE p1 = p2
  )
  SELECT STRING_AGG(IFNULL(latin, char), '')
  FROM UNNEST(SPLIT(word, '')) char
  LEFT JOIN pairs
  ON char = accent
));

-- Main Table deletion/creation
drop table `BIP.tarjeta_bip`;

create table `BIP.tarjeta_bip` as
--base cte will union all tables first, then field called "coordenadas" will be added to final table
with base as (
    select 
    CODIGO
    ,UPPER(ENTIDAD) as ENTIDAD
    ,null as NOMBRE_DE_FANTASIA
    ,DIRECCION
    ,COMUNA
    ,HORARIO as HORARIO_REFERENCIAL
    ,ESTE
    ,NORTE
    ,LONGITUD
    ,LATITUD
    ,'ESTANDAR ALTO' as TIPO

    from `BIP.estandard_alto`

    union distinct

    select 
    CODIGO
    ,UPPER(ENTIDAD) as ENTIDAD
    ,null as NOMBRE_DE_FANTASIA
    ,DIRECCION
    ,COMUNA
    ,HORARIO as HORARIO_REFERENCIAL
    ,ESTE
    ,NORTE
    ,LONGITUD
    ,LATITUD
    ,'ESTANDAR NORMAL' as TIPO

    from `BIP.estandard_normal`

    union distinct

    select 
    CODIGO
    ,UPPER(ENTIDAD) as ENTIDAD
    ,NOMBRE_FANTASIA as NOMBRE_DE_FANTASIA
    ,DIRECCION
    ,COMUNA
    ,HORARIO_REFERENCIAL
    ,ESTE
    ,NORTE
    ,LONGITUD
    ,LATITUD
    ,'RETAIL' as TIPO

    from `BIP.retail`

    union distinct

    select 
    CODIGO
    ,UPPER(ENTIDAD) as ENTIDAD
    ,NOMBRE_DE_FANTASIA_ as NOMBRE_DE_FANTASIA
    ,DIRECCI__N as DIRECCION
    ,COMUNA
    ,HORARIO_REFERENCIAL
    ,ESTE
    ,NORTE
    ,LONGITUD
    ,LATITUD
    ,'PUNTOS BIP' as TIPO

    from `BIP.puntos_bip`

    union distinct

    select 
    ROW_NUMBER() OVER (ORDER BY NOMBRE_FANTASIA, DIRECCION ASC) as CODIGO
    ,UPPER(ENTIDAD) as ENTIDAD
    ,NOMBRE_FANTASIA as NOMBRE_DE_FANTASIA
    ,DIRECCION
    ,COMUNA
    ,HORARIO_REFERENCIAL
    ,ESTE
    ,NORTE
    ,LONGITUD * case when ABS(LONGITUD) - FLOOR(ABS(LONGITUD))= 0 then 1/POWER(10,CAST(LENGTH(cast(ABS(LONGITUD) as string)) as integer) - 2) else 1 end as LONGITUD
    ,LATITUD * case when ABS(LATITUD) - FLOOR(ABS(LATITUD))= 0 then 1/POWER(10,CAST(LENGTH(cast(ABS(LATITUD) as string)) as integer) - 2) else 1 end as LATITUD
    ,'METRO' as TIPO

    from `BIP.metro`
    
)
, add_col as(
  select
  a.*
  ,FORMAT('%s\n%s\n%s',Coalesce(NOMBRE_DE_FANTASIA,''), CONCAT(a.DIRECCION,', ',a.COMUNA),Coalesce(a.HORARIO_REFERENCIAL,'Horario no disponible')) as FOR_TOOLTIP
  ,b.TOTAL_POBLACI__N_EFECTIVAMENTE_CENSADA as poblacion_total_comuna
  ,max(case when c.accion='Activación de carga remota' then 1 else 0 end) as act_crg_rmt
  ,max(case when c.accion='Carga de tarjeta' then 1 else 0 end) as crg_trj
  ,max(case when c.accion='Consulta de saldo' then 1 else 0 end) as cst_sld
  ,max(case when c.accion='Remplazo de tarjeta' then 1 else 0 end) as rmp_trj
  ,max(case when c.accion='Traspaso de saldo desde tarjeta dañada' then 1 else 0 end) as trns_sld_trj
  ,max(case when c.accion='Venta de tarjeta' then 1 else 0 end) as vnt_trj

  from base as a
  left join `BIP.poblacion_comuna` as b -- Adding the comuna total population
    on a.comuna=accent2latin(b.NOMBRE_COMUNA)
  left join `BIP.accion_x_tipo` c
    on a.TIPO=c.tipo
  group by 1,2,3,4,5,6,7,8,9,10,11,12,13
)
select
a.*
,ST_GEOGPOINT(LONGITUD, LATITUD) as COORDENADA
,CONCAT(LATITUD,',',LONGITUD) AS LOCATION
from add_col as a
;


