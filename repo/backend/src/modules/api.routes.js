const express = require('express');
const pool = require('../db/pool');
const { makeCrud, routerDe } = require('./crud');
const { exigir } = require('../middleware/auth');
const r = express.Router();
r.use(exigir('SUPERVISOR'));
r.use('/integracao-log', routerDe(makeCrud(pool, 'api.integracao_log', ['id','sistema','endpoint','payload','status_http'], 'id'), { criar: true, atualizar: false }));
r.use('/leitura-iot', routerDe(makeCrud(pool, 'api.leitura_iot', ['id','dispositivo','grandeza','valor','lida_em'], 'id'), { criar: true, atualizar: false }));
module.exports = r;
