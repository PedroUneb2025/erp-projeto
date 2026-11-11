const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();

r.use(exigir('SUPERVISOR'));
r.use('/cliente', routerDe(makeCrud(pool, 'sd.cliente', ['id','nome','documento','email','telefone','limite_credito'], 'nome')));
r.use('/oportunidade', routerDe(makeCrud(pool, 'sd.oportunidade', ['id','cliente_id','responsavel_id','valor_estimado','etapa'], 'id')));
r.use('/contrato', routerDe(makeCrud(pool, 'sd.contrato', ['id','cliente_id','inicio','fim','valor_mensal'], 'id')));
r.use('/pedido-venda', routerDe(makeCrud(pool, 'sd.pedido_venda', ['id','cliente_id','vendedor_id','data_pedido','status','total'], 'id'), { atualizar: true }));

r.post('/pedido-venda/:id/itens', async (req, res, next) => {
  try {
    const { material_id, quantidade, preco_unit } = req.body || {};
    const { rows } = await pool.query(
      `INSERT INTO sd.item_pedido_venda (pedido_id, material_id, quantidade, preco_unit)
       VALUES ($1,$2,$3,$4) ON CONFLICT (pedido_id, material_id)
       DO UPDATE SET quantidade = EXCLUDED.quantidade, preco_unit = EXCLUDED.preco_unit RETURNING *`,
      [req.params.id, material_id, quantidade, preco_unit]);
    res.status(201).json(rows[0]);
  } catch (e) { next(e); }
});
r.post('/pedido-venda/:id/faturar', exigir('GERENTE'), async (req, res, next) => {
  try {
    // cliente/DBA aprovam implicitamente; senão exige APROVADO
    await pool.query('CALL sd.sp_faturar_pedido($1,$2,$3)',
      [req.params.id, req.body?.deposito_id || 1, req.body?.dias_venc || 30]);
    res.json({ ok: true, message: 'Pedido faturado: NF, título e baixa de estoque gerados' });
  } catch (e) { next(e); }
});
r.get('/pedido-venda/:id/nota', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM sd.nota_fiscal WHERE pedido_id = $1', [req.params.id]);
    res.json(rows[0] || null);
  } catch (e) { next(e); }
});
module.exports = r;
