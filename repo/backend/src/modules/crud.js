// Fábrica de CRUD genérico com lista de colunas permitidas (anti-injection)
function makeCrud(pool, tabela, colunas, orderBy) {
  const id = colunas[0];
  return {
    async listar(q) {
      const where = [];
      const vals = [];
      const filtros = Object.keys(q).filter(k => colunas.includes(k));
      filtros.forEach((k, i) => { where.push(`${k} = $${i + 1}`); vals.push(q[k]); });
      const sql = `SELECT * FROM ${tabela}` +
        (where.length ? ' WHERE ' + where.join(' AND ') : '') +
        ` ORDER BY ${orderBy || id} LIMIT 200`;
      const { rows } = await pool.query(sql, vals);
      return rows;
    },
    async obter(v) {
      const { rows } = await pool.query(`SELECT * FROM ${tabela} WHERE ${id} = $1`, [v]);
      if (!rows[0]) throw Object.assign(new Error('Registro não encontrado'), { status: 404 });
      return rows[0];
    },
    async criar(dados) {
      const keys = Object.keys(dados).filter(k => colunas.includes(k) && k !== id);
      if (!keys.length) throw Object.assign(new Error('Nenhum campo válido'), { status: 400 });
      const vals = keys.map(k => dados[k]);
      const ph = keys.map((_, i) => `$${i + 1}`).join(',');
      const { rows } = await pool.query(
        `INSERT INTO ${tabela} (${keys.join(',')}) VALUES (${ph}) RETURNING *`, vals);
      return rows[0];
    },
    async atualizar(v, dados) {
      const keys = Object.keys(dados).filter(k => colunas.includes(k) && k !== id);
      if (!keys.length) throw Object.assign(new Error('Nenhum campo válido'), { status: 400 });
      const sets = keys.map((k, i) => `${k} = $${i + 2}`).join(',');
      const { rows } = await pool.query(
        `UPDATE ${tabela} SET ${sets} WHERE ${id} = $1 RETURNING *`, [v, ...keys.map(k => dados[k])]);
      if (!rows[0]) throw Object.assign(new Error('Registro não encontrado'), { status: 404 });
      return rows[0];
    },
    async remover(v) {
      const { rowCount } = await pool.query(`DELETE FROM ${tabela} WHERE ${id} = $1`, [v]);
      if (!rowCount) throw Object.assign(new Error('Registro não encontrado'), { status: 404 });
    },
  };
}

function routerDe(crud, { criar = true, atualizar = true, remover = false } = {}) {
  const express = require('express');
  const r = express.Router();
  r.get('/', async (req, res, next) => { try { res.json(await crud.listar(req.query)); } catch (e) { next(e); } });
  r.get('/:id', async (req, res, next) => { try { res.json(await crud.obter(req.params.id)); } catch (e) { next(e); } });
  if (criar) r.post('/', async (req, res, next) => { try { res.status(201).json(await crud.criar(req.body)); } catch (e) { next(e); } });
  if (atualizar) r.put('/:id', async (req, res, next) => { try { res.json(await crud.atualizar(req.params.id, req.body)); } catch (e) { next(e); } });
  if (remover) r.delete('/:id', async (req, res, next) => { try { await crud.remover(req.params.id); res.status(204).end(); } catch (e) { next(e); } });
  return r;
}

module.exports = { makeCrud, routerDe };
