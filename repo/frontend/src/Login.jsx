import React, { useState } from 'react';

export default function Login({ onLogin, erro }) {
  const [login, setLogin] = useState('');
  const [senha, setSenha] = useState('');
  return (
    <div className="tela-login">
      <form onSubmit={e => { e.preventDefault(); onLogin(login, senha); }}>
        <h1>ERP Avançado</h1>
        <p>Projeto Final de Banco de Dados</p>
        <input placeholder="Login" value={login} onChange={e => setLogin(e.target.value)} />
        <input type="password" placeholder="Senha" value={senha} onChange={e => setSenha(e.target.value)} />
        {erro && <div className="erro">{erro}</div>}
        <button type="submit">Entrar</button>
        <small>demo: admin / senha123</small>
      </form>
    </div>
  );
}
