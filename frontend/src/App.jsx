import React, { useEffect, useState, useCallback } from 'react';
import { api, login, setToken, getToken } from './api';
import Login from './Login.jsx';
import Dashboard from './Dashboard.jsx';
import Recursos from './Recursos.jsx';

const MENUS = [
  { id: 'dash', label: 'Dashboard', perfis: null },
  { id: 'clientes', label: 'Clientes', perfis: ['SUPERVISOR'] },
  { id: 'pedidos', label: 'Pedidos de Venda', perfis: ['SUPERVISOR'] },
  { id: 'estoque', label: 'Estoque', perfis: ['SUPERVISOR'] },
  { id: 'bi', label: 'BI / Relatórios', perfis: ['ANALISTA'] },
];

export default function App() {
  const [user, setUser] = useState(null);
  const [erro, setErro] = useState('');
  const [menu, setMenu] = useState('dash');

  useEffect(() => {
    if (getToken()) {
      // valida token buscando um endpoint protegido
      api('/api/bi/vendas-mensais').then(() => setUser(JSON.parse(localStorage.getItem('erp_user'))))
        .catch(() => setUser(null));
    }
  }, []);

  const fazerLogin = useCallback(async (l, s) => {
    setErro('');
    try {
      const r = await login(l, s);
      setToken(r.token);
      localStorage.setItem('erp_user', JSON.stringify(r.usuario));
      setUser(r.usuario);
    } catch (e) { setErro(e.message); }
  }, []);

  const sair = () => { setToken(null); localStorage.removeItem('erp_user'); setUser(null); };

  if (!user) return <Login onLogin={fazerLogin} erro={erro} />;

  const podeVer = m => !m.perfis || m.perfis.some(p => (user.perfis || []).includes(p)) ||
    user.perfis?.some(p => ['DBA', 'CEO', 'DIRETOR'].includes(p));

  return (
    <div className="app">
      <aside className="sidebar">
        <h1>ERP<span>Avançado</span></h1>
        <nav>
          {MENUS.filter(podeVer).map(m => (
            <button key={m.id} className={menu === m.id ? 'ativo' : ''} onClick={() => setMenu(m.id)}>
              {m.label}
            </button>
          ))}
        </nav>
        <div className="rodape">
          <div>{user.login} · {(user.perfis || []).join(', ')}</div>
          <button onClick={sair}>Sair</button>
        </div>
      </aside>
      <main>
        {menu === 'dash' && <Dashboard />}
        {menu === 'clientes' && <Recursos titulo="Clientes" endpoint="/api/sd/cliente" />}
        {menu === 'pedidos' && <Recursos titulo="Pedidos de Venda" endpoint="/api/sd/pedido-venda" />}
        {menu === 'estoque' && <Recursos titulo="Estoque" endpoint="/api/mm/estoque" />}
        {menu === 'bi' && <Recursos titulo="Vendas Mensais (BI)" endpoint="/api/bi/vendas-mensais" />}
      </main>
    </div>
  );
}
