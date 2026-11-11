const swaggerUi = require('swagger-ui-express');
const swaggerSpec = {
  openapi: '3.0.0',
  info: {
    title: 'ERP Avançado API',
    version: '1.0.0',
    description: 'Projeto Final de Banco de Dados Avançado — API REST modular',
  },
  servers: [{ url: '/' }],
  components: {
    securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
  },
  security: [{ bearerAuth: [] }],
  tags: [
    { name: 'Auth' }, { name: 'SYS' }, { name: 'FI' }, { name: 'RH' }, { name: 'MM' },
    { name: 'SD' }, { name: 'PP' }, { name: 'PS' }, { name: 'SM' }, { name: 'QM' },
    { name: 'AM' }, { name: 'GRC' }, { name: 'API' }, { name: 'BI' },
  ],
};
module.exports = { swaggerUi, swaggerSpec };
