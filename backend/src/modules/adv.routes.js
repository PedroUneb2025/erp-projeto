// Recursos avançados: obrigações acessórias (SPED/eSocial), previsão IA,
// detecção de fraude e exportação de auditoria (ELK/Splunk/BI)
const express = require('express');
const pool = require('../db/pool');
const { exigir } = require('../middleware/auth');
const r = express.Router();

// SPED/EFD do mês (texto do arquivo, pronto para salvar/gravar)
r.get('/sped-efd', exigir('DIRETOR'), async (req, res, next) => {
  try {
    const comp = req.query.competencia || new Date().toISOString().slice(0, 10);
    const { rows } = await pool.query('SELECT fi.fn_gerar_sped_efd($1::date) AS arquivo', [comp]);
    res.type('text/plain').send(rows[0].arquivo);
  } catch (e) { next(e); }
});

// eSocial da competência
r.get('/esocial', exigir('DIRETOR'), async (req, res, next) => {
  try {
    const comp = req.query.competencia || new Date().toISOString().slice(0, 10);
    const { rows } = await pool.query('SELECT rh.fn_gerar_esocial($1::date) AS arquivo', [comp]);
    res.type('text/plain').send(rows[0].arquivo);
  } catch (e) { next(e); }
});

// Registra entrega da obrigação
r.post('/obrigacoes/:tipo/entregar', exigir('DIRETOR'), async (req, res, next) => {
  try {
    const comp = req.body?.competencia || new Date().toISOString().slice(0, 10);
    await pool.query('CALL fi.sp_registrar_entrega($1, $2::date)', [req.params.tipo, comp]);
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// Previsão de demanda (IA — regressão sobre histórico de vendas)
r.get('/previsao-demanda', exigir('GERENTE'), async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM pp.fn_previsao_demanda($1)', [req.query.horizonte || 12]);
    res.json(rows);
  } catch (e) { next(e); }
});

// Gera e grava o MRP a partir da previsão
r.post('/mrp/gerar', exigir('GERENTE'), async (req, res, next) => {
  try {
    await pool.query('CALL pp.sp_gerar_mrp($1)', [req.body?.horizonte || 12]);
    res.json({ ok: true });
  } catch (e) { next(e); }
});

// Detecção de fraude/anomalias
r.get('/fraude/auditoria', exigir('DIRETOR'), async (_req, res, next) => {
  try { res.json((await pool.query('SELECT * FROM grc.vw_suspeitas_auditoria LIMIT 200')).rows); } catch (e) { next(e); }
});
r.get('/fraude/notas', exigir('DIRETOR'), async (_req, res, next) => {
  try { res.json((await pool.query('SELECT * FROM grc.vw_suspeitas_valor LIMIT 200')).rows); } catch (e) { next(e); }
});

// Auditoria em JSON para ingest (ELK/Splunk) — aceita ?limite=
r.get('/auditoria/json', exigir('DIRETOR'), async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT sys.fn_auditoria_json($1) AS eventos', [req.query.limite || 1000]);
    res.json(rows[0].eventos);
  } catch (e) { next(e); }
});

// CSV de views BI para Power BI/Metabase
r.get('/bi/:view.csv', exigir('ANALISTA'), async (req, res, next) => {
  try {
    const views = {
      'vendas-mensais': 'bi.vw_vendas_mensais',
      'fluxo-caixa': 'bi.vw_fluxo_caixa',
      'inadimplencia': 'bi.vw_inadimplencia',
      'impostos-periodo': 'bi.vw_impostos_periodo',
      'produtividade': 'bi.vw_produtividade',
    };
    const v = views[req.params.view];
    if (!v) return res.status(404).json({ erro: 'View inexistente', disponiveis: Object.keys(views) });
    const { rows } = await pool.query(`SELECT * FROM ${v}`);
    if (!rows.length) return res.type('text/csv').send('');
    const cols = Object.keys(rows[0]);
    const esc = s => String(s ?? '').replace(/"/g, '""');
    const csv = [cols.join(';'), ...rows.map(l => cols.map(c => `"${esc(l[c])}"`).join(';'))].join('\n');
    res.type('text/csv; charset=utf-8').attachment(`${req.params.view}.csv`).send(csv);
  } catch (e) { next(e); }
});

module.exports = r;
