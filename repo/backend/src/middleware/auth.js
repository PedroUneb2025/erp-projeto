const jwt = require('jsonwebtoken');
const { JWT_SECRET } = require('../auth/service');

function authN(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ erro: 'Token ausente' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ erro: 'Token inválido ou expirado' });
  }
}

// RBAC: perfis exigidos por rota. ADMIN/DBA/CEO veem tudo.
const HIERARQUIA = ['ANALISTA', 'SUPERVISOR', 'GERENTE', 'DIRETOR', 'CEO', 'DBA'];
function exigir(...perfisExigidos) {
  return (req, res, next) => {
    const perfis = (req.user?.perfis || []).map(p => p.toUpperCase());
    if (perfis.some(p => p === 'DBA' || p === 'CEO')) return next();
    const maxNivel = Math.max(0, ...perfis.map(p => HIERARQUIA.indexOf(p)).filter(i => i >= 0));
    const minExigido = Math.min(...perfisExigidos.map(p => HIERARQUIA.indexOf(p.toUpperCase())));
    if (perfis.some(p => perfisExigidos.includes(p.toUpperCase())) || maxNivel >= minExigido) return next();
    res.status(403).json({ erro: 'Acesso negado para o perfil ' + perfis.join(',') });
  };
}

module.exports = { authN, exigir };
