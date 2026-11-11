const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();
r.use(exigir('SUPERVISOR'));
r.use('/ativo', routerDe(makeCrud(pool, 'am.ativo', ['id','descricao','valor_aquisicao','data_aquisicao','vida_util_meses','depreciacao_acumulada'], 'id')));
r.use('/manutencao', routerDe(makeCrud(pool, 'am.manutencao', ['id','ativo_id','tipo','data_manut','custo'], 'id'), { criar: true, atualizar: true }));
r.post('/depreciar', async (_req, res, next) => {
  try { await pool.query('CALL am.sp_depreciar_ativos()'); res.json({ ok: true }); } catch (e) { next(e); }
});
module.exports = r;
