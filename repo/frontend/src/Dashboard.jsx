import React, { useEffect, useState } from 'react';
import { api } from './api';

export default function Dashboard() {
  const [cards, setCards] = useState(null);
  const [erro, setErro] = useState('');

  useEffect(() => {
    Promise.all([
      api('/api/bi/vendas-mensais'),
      api('/api/bi/fluxo-caixa').catch(() => []),
      api('/api/bi/estoque-critico').catch(() => []),
    ]).then(([vendas, caixa, critico]) => {
      const fat = vendas.reduce((s, v) => s + Number(v.faturamento || 0), 0);
      const pedidos = vendas.reduce((s, v) => s + Number(v.pedidos || 0), 0);
      const saldo = caixa.reduce((s, d) => s + Number(d.saldo_dia || 0), 0);
      setCards({ faturamento: fat, pedidos, saldoDia: saldo, itensCriticos: critico.length, vendas });
    }).catch(e => setErro(e.message));
  }, []);

  if (erro) return <div className="erro">{erro}</div>;
  if (!cards) return <p>Carregando dashboard…</p>;

  const maxi = Math.max(...cards.vendas.map(v => Number(v.faturamento || 0)), 1);

  return (
    <section className="dashboard">
      <h2>Dashboard gerencial</h2>
      <div className="cards">
        <div className="card"><small>Faturamento</small><strong>R$ {cards.faturamento.toLocaleString('pt-BR')}</strong></div>
        <div className="card"><small>Pedidos faturados</small><strong>{cards.pedidos}</strong></div>
        <div className="card"><small>Saldo de caixa projetado</small><strong>R$ {Math.round(cards.saldoDia).toLocaleString('pt-BR')}</strong></div>
        <div className="card alerta"><small>Itens de estoque crítico</small><strong>{cards.itensCriticos}</strong></div>
      </div>

      <h3>Vendas por mês</h3>
      <div className="grafico">
        {cards.vendas.map(v => (
          <div key={v.mes} className="barra" title={`${v.pedidos} pedidos`}>
            <div className="valor" style={{ height: `${(Number(v.faturamento || 0) / maxi) * 100}%` }} />
            <small>{String(v.mes).slice(0, 7)}</small>
          </div>
        ))}
        {cards.vendas.length === 0 && <p>Sem vendas faturadas ainda — fature um pedido na tela Pedidos.</p>}
      </div>
    </section>
  );
}
