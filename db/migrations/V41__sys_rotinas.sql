CREATE FUNCTION sys.fn_auditar() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE ator bigint := nullif(current_setting('app.usuario_id',true),'')::bigint;
BEGIN
 IF TG_OP='UPDATE' THEN NEW.updated_at:=now(); END IF;
 IF TG_OP='INSERT' THEN NEW.created_by:=coalesce(ator,NEW.created_by); END IF;
 INSERT INTO sys.auditorias(tabela,operacao,registro_id,antes,depois,created_by)
 VALUES(TG_TABLE_SCHEMA||'.'||TG_TABLE_NAME,TG_OP,coalesce(NEW.id,OLD.id),
 CASE WHEN TG_OP<>'INSERT' THEN to_jsonb(OLD) END,
 CASE WHEN TG_OP<>'DELETE' THEN to_jsonb(NEW) END,ator);
 RETURN coalesce(NEW,OLD);
END $$;
CREATE FUNCTION sys.fn_usuario_tem_permissao(p_usuario bigint,p_codigo text)
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT EXISTS(SELECT 1 FROM sys.usuarios_perfis up JOIN sys.perfis p ON p.id=up.perfil_id
 WHERE up.usuario_id=p_usuario AND up.deleted_at IS NULL AND p.deleted_at IS NULL AND
 (p.nome IN ('role_ceo','role_dba') OR EXISTS(
 SELECT 1 FROM sys.perfis_permissoes pp JOIN sys.permissoes pm ON pm.id=pp.permissao_id
 WHERE pp.perfil_id=p.id AND pp.deleted_at IS NULL AND pm.deleted_at IS NULL AND pm.codigo=p_codigo)))
$$;
CREATE FUNCTION sys.fn_registrar_acesso() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' OR (OLD.revogada_em IS NULL AND NEW.revogada_em IS NOT NULL) THEN
 INSERT INTO sys.log_acessos(usuario_id,evento,sessao_id,created_by)
 VALUES(NEW.usuario_id,CASE WHEN TG_OP='INSERT' THEN 'login' ELSE 'logout' END,NEW.id,NEW.usuario_id);
 END IF; RETURN NEW;
END $$;
CREATE TRIGGER trg_sessoes_acessos AFTER INSERT OR UPDATE ON sys.sessoes FOR EACH ROW EXECUTE FUNCTION sys.fn_registrar_acesso();
CREATE PROCEDURE sys.sp_revogar_sessoes(p_usuario bigint) LANGUAGE sql AS $$
 UPDATE sys.sessoes SET revogada_em=now(),updated_at=now() WHERE usuario_id=p_usuario AND revogada_em IS NULL;
$$;
CREATE VIEW sys.vw_usuarios_perfis AS
 SELECT up.usuario_id,array_agg(p.nome ORDER BY p.nome) AS perfis FROM sys.usuarios_perfis up
 JOIN sys.perfis p ON p.id=up.perfil_id WHERE up.deleted_at IS NULL AND p.deleted_at IS NULL GROUP BY up.usuario_id;
CREATE VIEW sys.vw_consultas_lentas AS
 SELECT queryid,calls,total_exec_time,mean_exec_time,rows FROM public.pg_stat_statements
 WHERE dbid=(SELECT oid FROM pg_database WHERE datname=current_database()) ORDER BY mean_exec_time DESC;
CREATE VIEW sys.vw_acessos_diarios AS SELECT created_at::date dia,evento,count(*) total FROM sys.log_acessos GROUP BY 1,2;
CREATE TRIGGER trg_perfis_auditoria BEFORE INSERT OR UPDATE OR DELETE ON sys.perfis FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_permissoes_auditoria BEFORE INSERT OR UPDATE OR DELETE ON sys.permissoes FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_perfis_permissoes_auditoria BEFORE INSERT OR UPDATE OR DELETE ON sys.perfis_permissoes FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_usuarios_perfis_auditoria BEFORE INSERT OR UPDATE OR DELETE ON sys.usuarios_perfis FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
CREATE TRIGGER trg_parametrizacoes_auditoria BEFORE INSERT OR UPDATE OR DELETE ON sys.parametrizacoes FOR EACH ROW EXECUTE FUNCTION sys.fn_auditar();
