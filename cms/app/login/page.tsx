'use client';

import { FormEvent, useState } from 'react';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      if (res.ok) {
        // Full page reload ensures cookie is sent with the next request
        // and middleware correctly reads the admin_token cookie.
        window.location.href = '/';
      } else {
        setError('Email hoặc mật khẩu không đúng.');
      }
    } catch {
      setError('Không thể kết nối đến server.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      style={{
        background: 'var(--surface)',
        borderRadius: 'var(--r3)',
        boxShadow: 'var(--shadow-lg)',
        padding: '48px 40px',
        width: '100%',
        maxWidth: 400,
        display: 'flex',
        flexDirection: 'column',
        gap: 24,
      }}
    >
      {/* Logo / Brand */}
      <div style={{ textAlign: 'center', marginBottom: 8 }}>
        <div
          style={{
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: 48,
            height: 48,
            borderRadius: 'var(--r2)',
            background: 'var(--brand)',
            marginBottom: 12,
          }}
        >
          <span style={{ color: '#fff', fontSize: 22, fontWeight: 700, fontFamily: 'Fraunces, serif' }}>A</span>
        </div>
        <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, color: 'var(--ink)', fontFamily: 'Fraunces, serif' }}>
          A2 Mluveni CMS
        </h1>
        <p style={{ margin: '4px 0 0', fontSize: 14, color: 'var(--ink-3)' }}>Đăng nhập để quản lý nội dung</p>
      </div>

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' }}>Email</span>
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            required
            autoComplete="email"
            placeholder="admin@example.com"
            style={{
              padding: '10px 14px',
              border: '1px solid var(--border-strong)',
              borderRadius: 'var(--r1)',
              fontSize: 14,
              color: 'var(--ink)',
              background: 'var(--surface)',
              outline: 'none',
              transition: 'border-color 0.15s',
            }}
          />
        </label>

        <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink-2)' }}>Mật khẩu</span>
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
            autoComplete="current-password"
            placeholder="••••••••"
            style={{
              padding: '10px 14px',
              border: '1px solid var(--border-strong)',
              borderRadius: 'var(--r1)',
              fontSize: 14,
              color: 'var(--ink)',
              background: 'var(--surface)',
              outline: 'none',
            }}
          />
        </label>

        {error && (
          <p
            style={{
              margin: 0,
              padding: '10px 14px',
              background: 'var(--error-bg)',
              color: 'var(--error)',
              borderRadius: 'var(--r1)',
              fontSize: 13,
            }}
          >
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={loading}
          style={{
            padding: '12px 0',
            background: loading ? 'var(--brand-soft)' : 'var(--brand)',
            color: loading ? 'var(--brand-ink)' : '#fff',
            border: 'none',
            borderRadius: 'var(--r1)',
            fontSize: 15,
            fontWeight: 600,
            cursor: loading ? 'not-allowed' : 'pointer',
            transition: 'background 0.15s',
          }}
        >
          {loading ? 'Đang đăng nhập...' : 'Đăng nhập'}
        </button>
      </form>
    </div>
  );
}
