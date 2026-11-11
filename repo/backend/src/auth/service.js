const pool = require('../db/pool');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-troque';
const JWT_TTL = process.env.JWT_TTL || '8h';

async function login(login, senha) {
  const { rows } = await pool.query(
    `SELECT u.id, u.login, u.senha_hash, u.ativo,
            COALESCE(array_agg(p.nome) FILTER (WHERE p.nome IS NOT NULL), '{}') AS perfis
       FROM sys.usuario u
       LEFT JOIN sys.usuario_perfil up ON up.usuario_id = u.id
       LEFT JOIN sys.perfil p ON p.id = up.perfil_id
      WHERE u.login = $1 GROUP BY u.id`, [login]);
  const u = rows[0];
  if (!u || !u.ativo) throw Object.assign(new Error('Credenciais inválidas'), { status: 401 });
  // suporta hash bcrypt (app) e crypt() do postgres (seed)
  let ok = false;
  try { ok = bcrypt.compareSync(senha, u.senha_hash); } catch { ok = false; }
  if (!ok) {
    const r = await pool.query('SELECT $1 = senha_hash AS ok FROM sys.usuario WHERE id=$2', [senha, u.id]);
    ok = r.rows[0]?.ok;
  }
  if (!ok) throw Object.assign(new Error('Credenciais inválidas'), { status: 401 });

  await pool.query('UPDATE sys.usuario SET ultimo_acesso = now() WHERE id = $1', [u.id]);
  const token = jwt.sign({ sub: u.id, login: u.login, perfis: u.perfis }, JWT_SECRET, { expiresIn: JWT_TTL });
  return { token, usuario: { id: u.id, login: u.login, perfis: u.perfis } };
}

module.exports = { login, JWT_SECRET };
