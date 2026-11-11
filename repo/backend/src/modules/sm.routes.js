const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();
r.use(exigir('SUPERVISOR'));
r.use('/ordem-servico', routerDe(makeCrud(pool, 'sm.ordem_servico', ['id','cliente_id','tecnico_id','descricao','prazo_sla','fechada_em','status'], 'id'), { atualizar: true }));
r.get('/sla', async (_req, res, next) => {
  try { res.json((await pool.query('SELECT * FROM bi.vw_sla_servicos')).rows); } catch (e) { next(e); }
});
module.exports = r;
