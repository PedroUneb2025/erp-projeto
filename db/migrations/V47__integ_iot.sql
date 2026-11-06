CREATE TABLE integ.resumos_sensores (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 created_by bigint, deleted_at timestamptz,
 sensor text NOT NULL, metrica text NOT NULL, unidade text NOT NULL, hora timestamptz NOT NULL, quantidade integer NOT NULL CHECK(quantidade>0), media double precision NOT NULL, minimo double precision NOT NULL, maximo double precision NOT NULL, UNIQUE(sensor,metrica,unidade,hora)
);
CREATE INDEX ix_resumos_sensores_hora ON integ.resumos_sensores(hora);
CREATE VIEW integ.vw_sensores_horarios AS SELECT sensor,metrica,unidade,hora,quantidade,media,minimo,maximo FROM integ.resumos_sensores WHERE deleted_at IS NULL;
CREATE TRIGGER trg_resumos_sensores_auditoria BEFORE INSERT OR UPDATE OR DELETE ON integ.resumos_sensores FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
