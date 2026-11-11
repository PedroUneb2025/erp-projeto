const express = require('express');
const r = express.Router();
const { login } = require('../auth/service');

r.post('/login', async (req, res, next) => {
  try {
    const { login: l, senha } = req.body || {};
    if (!l || !senha) return res.status(400).json({ erro: 'Informe login e senha' });
    res.json(await login(l, senha));
  } catch (e) { next(e); }
});
module.exports = r;
