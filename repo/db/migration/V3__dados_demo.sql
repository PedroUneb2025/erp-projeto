-- V3: dados de demonstração para testar o fluxo completo
INSERT INTO sys.usuario (login, email, senha_hash)
VALUES ('admin', 'admin@empresa.com', crypt('senha123', gen_salt('bf')));

-- Clientes e fornecedor
INSERT INTO sd.cliente (nome, documento, email, limite_credito) VALUES
 ('Comercial Alfa Ltda', '12345678000199', 'alfa@cliente.com', 50000),
 ('Indústria Beta S/A',  '98765432000155', 'beta@cliente.com', 120000);
INSERT INTO mm.fornecedor (razao_social, cnpj, email) VALUES
 ('Supridora Gama ME', '11222333000181', 'vendas@gamma.com');

-- Materiais (com preço de venda para os perecíveis)
INSERT INTO mm.material (sku, descricao, unidade, custo_medio, preco_venda, estoque_minimo) VALUES
 ('SKU-TECLADO',  'Teclado mecânico',       'UN', 150.00,  289.90, 10),
 ('SKU-MONITOR',  'Monitor 24 polegadas',   'UN', 520.00,  899.90, 5),
 ('SKU-MEMORIA',  'Memória RAM 16GB',       'UN', 210.00,  359.90, 8),
 ('SKU-SSD',      'SSD NVMe 1TB',           'UN', 380.00,  649.90, 6);

-- Estoque inicial (entrada manual de 20/10 de cada)
INSERT INTO mm.movimento_estoque (material_id, deposito_id, tipo, quantidade, origem)
SELECT m.id, 1, 'E', 50, 'ESTOQUE_INICIAL' FROM mm.material m;

-- Colaboradores (CPF mascarado para demo; chave 'demo-key' só para ambiente de testes)
INSERT INTO rh.colaborador (nome, cpf_hash, cpf_cript, departamento_id, cargo_id, admissao)
SELECT 'Maria Souza', 'a'::text, '\x00'::bytea, NULL, g.id, CURRENT_DATE
  FROM rh.cargo g WHERE g.nivel = 'GERENTE';
INSERT INTO rh.colaborador (nome, cpf_hash, cpf_cript, departamento_id, cargo_id, admissao)
SELECT 'João Lima', 'b'::text, '\x00'::bytea, NULL, g.id, CURRENT_DATE
  FROM rh.cargo g WHERE g.nivel = 'SUPERVISOR';

-- Vendedor responsável
UPDATE sd.oportunidade SET responsavel_id = (SELECT id FROM rh.colaborador LIMIT 1) WHERE FALSE;

-- Pedido de venda aprovado (pronto para faturar)
INSERT INTO sd.pedido_venda (cliente_id, vendedor_id)
VALUES (1, (SELECT id FROM rh.colaborador LIMIT 1));
UPDATE sd.pedido_venda SET status = 'APROVADO' WHERE id = 1000;
INSERT INTO sd.item_pedido_venda (pedido_id, material_id, quantidade, preco_unit) VALUES
 (1000, 1, 5, 289.90),
 (1000, 2, 3, 899.90);

-- Pedido de compra aprovado (pronto para receber)
INSERT INTO mm.pedido_compra (fornecedor_id) VALUES (1);
UPDATE mm.pedido_compra SET status = 'APROVADO' WHERE id = 5000;
INSERT INTO mm.item_pedido_compra (pedido_id, material_id, quantidade, preco_unit) VALUES
 (5000, 3, 30, 210.00),
 (5000, 4, 20, 380.00);

-- Contas bancária e lançamentos para conciliação
INSERT INTO fi.conta_bancaria (banco, agencia, numero, saldo) VALUES
 ('Banco Demo', '0001', '12345-6', 25000.00);
INSERT INTO fi.plano_contas (codigo, descricao, tipo) VALUES
 ('1.1.1', 'Caixa Geral', 'A'), ('4.1', 'Receita de Vendas', 'R');
INSERT INTO fi.lancamento (conta_debito, conta_credito, valor, historico) VALUES
 (5, 6, 1000.00, 'Recebimento de teste');

-- Extrato conciliável (mesmo valor/data do lançamento acima)
INSERT INTO fi.extrato_bancario (conta_id, data_mov, identificacao, valor) VALUES
 (1, CURRENT_DATE, 'DOC-001', 1000.00);
