'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useS, LocaleSwitcher } from '../lib/i18n';

const NAV_ITEMS = [
  {
    href: '/', exact: true,
    key: 'exercises' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /></svg>,
  },
  {
    href: '/courses', exact: false,
    key: 'courses' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" /><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" /></svg>,
  },
  {
    href: '/mock-tests', exact: false,
    key: 'mockTests' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6" /><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18" /><path d="M4 22h16" /><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22" /><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22" /><path d="M18 2H6v7a6 6 0 0 0 12 0V2z" /></svg>,
  },
  {
    href: '/learners', exact: false,
    key: 'learners' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></svg>,
  },
  {
    href: '/modules', exact: false,
    key: 'modules' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 6h18M3 12h18M3 18h18" /></svg>,
  },
  {
    href: '/skills', exact: false,
    key: 'skills' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" /></svg>,
  },
  {
    href: '/vocabulary', exact: false,
    key: 'vocabulary' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M12 20h9" /><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" /></svg>,
  },
  {
    href: '/grammar', exact: false,
    key: 'grammar' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M4 6h16M4 12h16M4 18h7" /></svg>,
  },
  {
    href: '/guide', exact: false,
    key: 'guide' as const,
    icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="10" /><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3" /><line x1="12" y1="17" x2="12.01" y2="17" /></svg>,
  },
];

export function CmsSidebar() {
  const pathname = usePathname();
  const s = useS();

  function isActive(href: string, exact: boolean) {
    if (exact) return pathname === href;
    return pathname.startsWith(href);
  }

  return (
    <aside style={{
      width: 248, minWidth: 248, height: '100vh', position: 'sticky', top: 0,
      background: 'var(--accent)', display: 'flex', flexDirection: 'column', overflow: 'hidden',
    }}>
      {/* Logo */}
      <div style={{ padding: '24px 20px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: 10, background: 'var(--brand)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3z" />
              <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
              <line x1="12" y1="19" x2="12" y2="23" />
              <line x1="8" y1="23" x2="16" y2="23" />
            </svg>
          </div>
          <div>
            <div style={{ fontFamily: 'Fraunces, serif', fontSize: 15, fontWeight: 700, color: '#fff', lineHeight: 1.1 }}>A2 Mluveni</div>
            <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.45)', marginTop: 1, letterSpacing: 0.3 }}>Sprint CMS</div>
          </div>
        </div>
      </div>

      <div style={{ height: 1, background: 'rgba(255,255,255,0.08)', margin: '0 20px' }} />

      {/* Nav */}
      <nav style={{ padding: '12px 10px', flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
        {NAV_ITEMS.map(item => {
          const active = isActive(item.href, item.exact);
          return (
            <Link key={item.href} href={item.href} style={{
              display: 'flex', alignItems: 'center', gap: 10,
              padding: '9px 12px', borderRadius: 'var(--r2)',
              color: active ? '#fff' : 'rgba(255,255,255,0.55)',
              background: active ? 'rgba(255,255,255,0.12)' : 'transparent',
              fontSize: 14, fontWeight: active ? 600 : 400,
              textDecoration: 'none', transition: 'background 120ms ease, color 120ms ease',
            }}>
              <span style={{ opacity: active ? 1 : 0.8, flexShrink: 0 }}>{item.icon}</span>
              {s.nav[item.key]}
            </Link>
          );
        })}
      </nav>

      {/* Footer: locale switcher + version */}
      <div style={{ padding: '12px 10px', borderTop: '1px solid rgba(255,255,255,0.08)', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <LocaleSwitcher />
        <div style={{ padding: '6px 12px', borderRadius: 'var(--r2)', background: 'rgba(255,255,255,0.04)' }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.3)', letterSpacing: 0.4, fontWeight: 600, marginBottom: 1 }}>VERSION</div>
          <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)' }}>A2 Mluveni Sprint v1</div>
        </div>
      </div>
    </aside>
  );
}
