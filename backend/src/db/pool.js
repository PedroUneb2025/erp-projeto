// Pool de conexões PostgreSQL — DATABASE_URL vem do ambiente (Neon/Render/local)
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL && process.env.DATABASE_URL.includes('neon')
    ? { rejectUnauthorized: false }
    : undefined,
  max: 10,
});

// Login de app: trocar para usuário com menos privilégio em produção
module.exports = pool;
