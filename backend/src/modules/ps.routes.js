const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();
r.use(exigir('SUPERVISOR'));
r.use('/projeto', routerDe(makeCrud(pool, 'ps.projeto', ['id','nome','gerente_id','orcamento','inicio','fim','status'], 'id')));
r.use('/tarefa', routerDe(makeCrud(pool, 'ps.tarefa', ['id','projeto_id','descricao','responsavel_id','inicio','fim','percentual'], 'id')));
module.exports = r;
