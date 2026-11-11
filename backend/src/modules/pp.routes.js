const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();
r.use(exigir('SUPERVISOR'));
r.use('/bom', routerDe(makeCrud(pool, 'pp.bom', ['produto_id','componente_id','quantidade'], 'produto_id')));
r.use('/ordem-producao', routerDe(makeCrud(pool, 'pp.ordem_producao', ['id','produto_id','quantidade','inicio_previsto','fim_previsto','status'], 'id')));
r.use('/mrp', routerDe(makeCrud(pool, 'pp.mrp', ['id','material_id','horizonte_semanas','demanda_prevista','demanda_gerada_por_ia'], 'id'), { criar: true, atualizar: true }));
r.post('/ordem-producao/:id/apontar', async (req, res, next) => {
  try {
    const { quantidade_produzida, quantidade_refugo, colaborador_id } = req.body || {};
    const { rows } = await pool.query(
      `INSERT INTO pp.apontamento_producao (ordem_id, colaborador_id, quantidade_produzida, quantidade_refugo)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [req.params.id, colaborador_id || null, quantidade_produzida, quantidade_refugo || 0]);
    res.status(201).json(rows[0]);
  } catch (e) { next(e); }
});
module.exports = r;
