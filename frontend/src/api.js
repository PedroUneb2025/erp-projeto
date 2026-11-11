const BASE = import.meta.env.VITE_API_URL || '';
const key = 'erp_token';

export const getToken = () => localStorage.getItem(key);
export const setToken = t => t ? localStorage.setItem(key, t) : localStorage.removeItem(key);

export async function api(path, { method = 'GET', body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(getToken() ? { authorization: `Bearer ${getToken()}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (res.status === 401) { setToken(null); location.reload(); }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.erro || `Erro HTTP ${res.status}`);
  return data;
}

export const login = (login, senha) => api('/api/auth/login', { method: 'POST', body: { login, senha } });
