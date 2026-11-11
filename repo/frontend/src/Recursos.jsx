import React, { useEffect, useState } from 'react';
import { api } from './api';

export default function Recursos({ titulo, endpoint }) {
  const [linhas, setLinhas] = useState([]);
  const [erro, setErro] = useState('');
  const [carregando, setCarregando] = useState(true);

  useEffect(() => {
    api(endpoint).then(setLinhas).catch(e => setErro(e.message)).finally(() => setCarregando(false));
  }, [endpoint]);

  const colunas = linhas.length ? Object.keys(linhas[0]).slice(0, 8) : [];

  return (
    <section>
      <h2>{titulo}</h2>
      {carregando && <p>Carregando…</p>}
      {erro && <div className="erro">{erro}</div>}
      {linhas.length > 0 && (
        <table>
          <thead><tr>{colunas.map(c => <th key={c}>{c}</th>)}</tr></thead>
          <tbody>
            {linhas.map((l, i) => (
              <tr key={i}>{colunas.map(c => {
                const v = l[c];
                return <td key={c}>{v === null ? '—' : typeof v === 'object' ? JSON.stringify(v) : String(v)}</td>;
              })}</tr>
            ))}
          </tbody>
        </table>
      )}
      {!carregando && !erro && linhas.length === 0 && <p>Nenhum registro.</p>}
    </section>
  );
}
