const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();

r.use(exigir('DBA'));
// rotas específicas ANTES dos CRUDs (senão /auditoria casa com /usuario/:id)
r.get('/auditoria', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT data_evento, usuario_db, tabela, operacao
         FROM sys.log_auditoria
        WHERE ($1::text IS NULL OR tabela ILIKE '%'||$1||'%')
        ORDER BY data_evento DESC LIMIT 100`, [req.query.tabela || null]);
    res.json(rows);
  } catch (e) { next(e); }
});
r.get('/parametros', async (_req, res, next) => {
  try { res.json((await pool.query('SELECT * FROM sys.parametro')).rows); } catch (e) { next(e); }
});
const usuario = routerDe(makeCrud(pool, 'sys.usuario',
  ['id', 'login', 'email', 'ativo'], 'login'), { atualizar: true, remover: true });
const perfil = routerDe(makeCrud(pool, 'sys.perfil', ['id', 'nome', 'descricao'], 'nome'));
r.use('/usuario', usuario);
r.use('/perfil', perfil);
module.exports = r;
