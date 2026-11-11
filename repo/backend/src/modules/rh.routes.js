const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();

r.use(exigir('GERENTE'));
r.use('/departamento', routerDe(makeCrud(pool, 'rh.departamento', ['id','nome','gerente_id'], 'nome')));
r.use('/cargo', routerDe(makeCrud(pool, 'rh.cargo', ['id','nome','nivel','salario_base'], 'nome')));
r.use('/beneficio', routerDe(makeCrud(pool, 'rh.beneficio', ['id','nome','tipo','custo_mensal'], 'nome')));
r.use('/vaga', routerDe(makeCrud(pool, 'rh.vaga', ['id','cargo_id','departamento_id','titulo','quantidade','aberta_em','encerrada_em'], 'aberta_em')));
r.use('/candidato', routerDe(makeCrud(pool, 'rh.candidato', ['id','vaga_id','nome','email','curriculo','etapa'], 'id'), { criar: true, atualizar: true }));

// Colaboradores: apenas DBA/CEO/Diretor (dados sensíveis com CPF criptografado)
r.use('/colaborador', exigir('DIRETOR'), routerDe(makeCrud(pool, 'rh.colaborador',
  ['id','nome','departamento_id','cargo_id','admissao','demissao','ativo'], 'nome')));

r.get('/colaborador-publico', async (_req, res, next) => {
  try { res.json((await pool.query('SELECT * FROM rh.vw_colaborador_publico')).rows); } catch (e) { next(e); }
});
r.post('/cadastrar-colaborador', exigir('DIRETOR'), async (req, res, next) => {
  try {
    const { nome, cpf, departamento_id, cargo_id, chave } = req.body || {};
    if (!nome || !cpf) return res.status(400).json({ erro: 'Informe nome e cpf' });
    const { rows } = await pool.query(
      'SELECT rh.fn_cadastra_colaborador($1,$2,$3,$4,$5) AS id',
      [nome, cpf, departamento_id || null, cargo_id || null, chave || process.env.CPF_KEY || 'demo-key']);
    res.status(201).json({ id: rows[0].id });
  } catch (e) { next(e); }
});
r.post('/gerar-folha', exigir('DIRETOR'), async (req, res, next) => {
  try {
    await pool.query('CALL rh.sp_gerar_folha($1)', [req.body?.competencia || new Date()]);
    res.json({ ok: true });
  } catch (e) { next(e); }
});
module.exports = r;
