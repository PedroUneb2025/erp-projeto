const express = require('express');
const cors = require('cors');
const { swaggerUi, swaggerSpec } = require('./swagger');
const { authN } = require('./middleware/auth');

const app = express();
app.use(cors());
app.use(express.json());

// Documentação interativa
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Login público
app.use('/api/auth', require('./modules/auth.routes'));

// Módulos protegidos (JWT + RBAC em cada router)
app.use('/api/usuarios',   authN, require('./modules/sys.routes'));
app.use('/api/fi',         authN, require('./modules/fi.routes'));
app.use('/api/rh',         authN, require('./modules/rh.routes'));
app.use('/api/mm',         authN, require('./modules/mm.routes'));
app.use('/api/sd',         authN, require('./modules/sd.routes'));
app.use('/api/pp',         authN, require('./modules/pp.routes'));
app.use('/api/ps',         authN, require('./modules/ps.routes'));
app.use('/api/sm',         authN, require('./modules/sm.routes'));
app.use('/api/qm',         authN, require('./modules/qm.routes'));
app.use('/api/am',         authN, require('./modules/am.routes'));
app.use('/api/grc',        authN, require('./modules/grc.routes'));
app.use('/api/api',        authN, require('./modules/api.routes'));
app.use('/api/bi',         authN, require('./modules/bi.routes'));
app.use('/api/adv',        authN, require('./modules/adv.routes'));

// Healthcheck para Render/monitoramento
app.get('/health', async (_req, res) => {
  try {
    const { Pool } = require('pg');
    const pool = require('./db/pool');
    await pool.query('SELECT 1');
    res.json({ status: 'ok', banco: 'conectado' });
  } catch (e) {
    res.status(503).json({ status: 'erro', banco: e.message });
  }
});

// Erros centralizados
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ erro: err.message });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`ERP API rodando na porta ${PORT} — docs em /api-docs`));
