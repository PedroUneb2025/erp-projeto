const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('node:child_process');

// Sobe o servidor numa porta de teste e valida o fluxo principal contra o banco real
const BASE = 'http://127.0.0.1:3999';
let server;

test.before(async () => {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL obrigatório para os testes');
  process.env.PORT = '3999';
  server = spawn('node', ['src/server.js'], { stdio: 'inherit', env: process.env });
  await new Promise(r => setTimeout(r, 1500));
});

let token;

test('health check com banco conectado', async () => {
  const res = await fetch(`${BASE}/health`);
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.strictEqual(body.banco, 'conectado');
});

test('login com usuário seed (admin/senha123)', async () => {
  const res = await fetch(`${BASE}/api/auth/login`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ login: 'admin', senha: 'senha123' }),
  });
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.ok(body.token);
  token = body.token;
});

const H = () => ({ 'content-type': 'application/json', authorization: `Bearer ${token}` });

test('RBAC: dashboard de BI acessível', async () => {
  const res = await fetch(`${BASE}/api/bi/vendas-mensais`, { headers: H() });
  assert.strictEqual(res.status, 200);
  await res.json();
});

test('lista de clientes', async () => {
  const res = await fetch(`${BASE}/api/sd/cliente`, { headers: H() });
  const rows = await res.json();
  assert.ok(Array.isArray(rows) && rows.length >= 2);
});

test('cria pedido de venda e o total é recalculado pelo trigger', async () => {
  const ped = await (await fetch(`${BASE}/api/sd/pedido-venda`, {
    method: 'POST', headers: H(), body: JSON.stringify({ cliente_id: 1 }),
  })).json();
  await fetch(`${BASE}/api/sd/pedido-venda/${ped.id}/itens`, {
    method: 'POST', headers: H(),
    body: JSON.stringify({ material_id: 1, quantidade: 2, preco_unit: 289.90 }),
  });
  const upd = await (await fetch(`${BASE}/api/sd/pedido-venda/${ped.id}`, {
    method: 'PUT', headers: H(), body: JSON.stringify({ status: 'APROVADO' }),
  })).json();
  assert.strictEqual(Number(upd.total), 579.80);
});

test('fatura o pedido: procedure completa roda pelo endpoint', async () => {
  const peds = await (await fetch(`${BASE}/api/sd/pedido-venda`, { headers: H() })).json();
  const ped = peds.find(p => p.status === 'APROVADO');
  const res = await fetch(`${BASE}/api/sd/pedido-venda/${ped.id}/faturar`, {
    method: 'POST', headers: H(), body: JSON.stringify({}) });
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.ok(body.ok);
});

test('auditoria registrou eventos', async () => {
  const res = await fetch(`${BASE}/api/sys/auditoria`, { headers: H() });
  const rows = await res.json();
  assert.ok(rows.length > 0);
});

test.after(() => { server?.kill(); });
