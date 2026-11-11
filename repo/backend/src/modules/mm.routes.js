const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();

r.use(exigir('SUPERVISOR'));
r.use('/material', routerDe(makeCrud(pool, 'mm.material', ['id','sku','descricao','unidade','custo_medio','preco_venda','estoque_minimo','tipo'], 'sku')));
r.use('/deposito', routerDe(makeCrud(pool, 'mm.deposito', ['id','nome'], 'nome')));
r.use('/fornecedor', routerDe(makeCrud(pool, 'mm.fornecedor', ['id','razao_social','cnpj','email','ativo'], 'razao_social')));
r.use('/pedido-compra', routerDe(makeCrud(pool, 'mm.pedido_compra', ['id','fornecedor_id','data_pedido','status'], 'id')));
r.use('/estoque', routerDe(makeCrud(pool, 'mm.estoque', ['material_id','deposito_id','quantidade'], 'material_id'), { criar: false, atualizar: false }));
r.use('/inventario', routerDe(makeCrud(pool, 'mm.inventario', ['id','deposito_id','data_inv','status'], 'id')));

r.post('/pedido-compra/:id/itens', async (req, res, next) => {
  try {
    const { material_id, quantidade, preco_unit } = req.body || {};
    const { rows } = await pool.query(
      `INSERT INTO mm.item_pedido_compra (pedido_id, material_id, quantidade, preco_unit)
       VALUES ($1,$2,$3,$4) ON CONFLICT (pedido_id, material_id)
       DO UPDATE SET quantidade = EXCLUDED.quantidade, preco_unit = EXCLUDED.preco_unit RETURNING *`,
      [req.params.id, material_id, quantidade, preco_unit]);
    res.status(201).json(rows[0]);
  } catch (e) { next(e); }
});
r.post('/movimento', async (req, res, next) => {
  try {
    const { material_id, deposito_id, tipo, quantidade, origem } = req.body || {};
    const { rows } = await pool.query(
      `INSERT INTO mm.movimento_estoque (material_id, deposito_id, tipo, quantidade, origem)
       VALUES ($1,$2,$3,$4,$5) RETURNING id`,
      [material_id, deposito_id || 1, tipo, quantidade, origem || 'API']);
    res.status(201).json({ id: rows[0].id });
  } catch (e) { next(e); }
});
r.post('/receber-compra/:id', async (req, res, next) => {
  try {
    await pool.query('CALL mm.sp_receber_compra($1,$2,$3)',
      [req.params.id, req.body?.deposito_id || 1, req.body?.dias_venc || 30]);
    res.json({ ok: true });
  } catch (e) { next(e); }
});
r.get('/:id(historico)?', async (req, res, next) => { next(); });
module.exports = r;
