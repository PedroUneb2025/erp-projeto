const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();

r.use(exigir('DIRETOR'));
r.use('/plano-contas', routerDe(makeCrud(pool, 'fi.plano_contas', ['id','codigo','descricao','tipo','pai_id'], 'codigo')));
r.use('/conta-bancaria', routerDe(makeCrud(pool, 'fi.conta_bancaria', ['id','banco','agencia','numero','saldo'], 'id')));
r.use('/conta-pagar', routerDe(makeCrud(pool, 'fi.conta_pagar', ['id','fornecedor_id','descricao','valor','vencimento','pagamento','status'], 'vencimento')));
r.use('/conta-receber', routerDe(makeCrud(pool, 'fi.conta_receber', ['id','cliente_id','pedido_id','valor','vencimento','recebimento','status'], 'vencimento')));
r.use('/orcamento', routerDe(makeCrud(pool, 'fi.orcamento', ['id','centro_custo','ano','valor_previsto'], 'ano')));
r.use('/extrato', routerDe(makeCrud(pool, 'fi.extrato_bancario', ['id','conta_id','data_mov','identificacao','valor','conciliado','lancamento_id'], 'data_mov')));
r.use('/tributo', routerDe(makeCrud(pool, 'fi.tributo', ['id','nome','tipo','aliquota'], 'nome')));

r.post('/baixar-recebimento/:id', exigir('GERENTE'), async (req, res, next) => {
  try {
    await pool.query('CALL fi.sp_baixar_recebimento($1, $2)', [req.params.id, req.body.conta_id || 1]);
    res.json({ ok: true });
  } catch (e) { next(e); }
});
r.post('/conciliar/:conta', exigir('GERENTE'), async (req, res, next) => {
  try {
    await pool.query('CALL fi.sp_conciliar_extrato($1)', [req.params.conta]);
    res.json({ ok: true });
  } catch (e) { next(e); }
});
r.post('/impostos-nota/:notaId', exigir('GERENTE'), async (req, res, next) => {
  try {
    await pool.query('CALL fi.sp_calcular_impostos_nota($1)', [req.params.notaId]);
    res.json({ ok: true });
  } catch (e) { next(e); }
});
module.exports = r;
