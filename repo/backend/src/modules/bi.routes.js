const express = require('express');
const pool = require('../db/pool');
const { exigir } = require('../middleware/auth');
const r = express.Router();
r.use(exigir('ANALISTA')); // analista e acima

const views = {
  'vendas-mensais': 'bi.vw_vendas_mensais',
  'estoque-critico': 'bi.vw_estoque_critico',
  'fluxo-caixa': 'bi.vw_fluxo_caixa',
  'inadimplencia': 'bi.vw_inadimplencia',
  'sla-servicos': 'bi.vw_sla_servicos',
  'impostos-periodo': 'bi.vw_impostos_periodo',
  'produtividade': 'bi.vw_produtividade',
};

r.get('/:view', async (req, res, next) => {
  try {
    const v = views[req.params.view];
    if (!v) return res.status(404).json({ erro: 'View inexistente', disponiveis: Object.keys(views) });
    res.json((await pool.query(`SELECT * FROM ${v} LIMIT 500`)).rows);
  } catch (e) { next(e); }
});
r.get('/margem/produto', async (_req, res, next) => {
  try {
    await pool.query('REFRESH MATERIALIZED VIEW bi.mv_margem_produto');
    res.json((await pool.query('SELECT * FROM bi.mv_margem_produto')).rows);
  } catch (e) { next(e); }
});
module.exports = r;
