// CMS Shell — sidebar + topbar + content area

const NAV = [
  { id: 'dashboard', label: 'Bảng điều khiển', icon: 'home' },
  { id: 'courses', label: 'Khóa học', icon: 'book', count: 3 },
  { id: 'mock-list', label: 'Mock test', icon: 'trophy', count: 8 },
  { id: 'learners', label: 'Học viên', icon: 'users', count: 2140 },
  { id: 'media', label: 'Thư viện audio', icon: 'media' },
  { id: 'settings', label: 'Cài đặt', icon: 'gear' },
];

function CMSShell({ children, route, go }) {
  return (
    <div style={{ display: 'flex', height: '100vh', background: C.bg, color: C.ink }}>
      {/* Sidebar */}
      <aside style={{ width: 248, flexShrink: 0, background: C.panel, borderRight: '1px solid ' + C.border, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '20px 18px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: 9, background: C.brand, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: C.display, fontWeight: 700, fontSize: 18, fontVariationSettings: '"opsz" 144', flexShrink: 0 }}>A</div>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontFamily: C.display, fontSize: 15, fontWeight: 600, letterSpacing: -0.2, lineHeight: 1.05, whiteSpace: 'nowrap' }}>A2 Sprint</div>
            <div style={{ fontSize: 10.5, color: C.ink3, fontWeight: 600, letterSpacing: 0.4, textTransform: 'uppercase', whiteSpace: 'nowrap' }}>CMS · v1.4</div>
          </div>
        </div>

        <nav style={{ padding: '8px 10px', display: 'flex', flexDirection: 'column', gap: 1 }}>
          {NAV.map(n => {
            const active = route.page === n.id || (n.id === 'courses' && route.page === 'course-detail') || (n.id === 'courses' && route.page === 'editor') || (n.id === 'mock-list' && route.page === 'mock') || (n.id === 'learners' && route.page === 'learner-detail');
            return (
              <button key={n.id} className={'nav-item ' + (active ? 'active' : '')} onClick={() => go(n.id)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 10,
                  padding: '8px 10px', borderRadius: 8, border: 'none',
                  background: active ? C.surface : 'transparent',
                  color: active ? C.ink : C.ink2,
                  fontSize: 13.5, fontWeight: active ? 600 : 500,
                  cursor: 'pointer', textAlign: 'left',
                  boxShadow: active ? C.shadowSm : 'none',
                }}>
                <CIcon name={n.icon} size={17} color={active ? C.brand : C.ink3} />
                <span style={{ flex: 1 }}>{n.label}</span>
                {n.count !== undefined && (
                  <span style={{ fontSize: 11, color: C.ink3, fontFamily: C.mono }}>{n.count.toLocaleString('vi')}</span>
                )}
              </button>
            );
          })}
        </nav>

        <div style={{ flex: 1 }} />

        <div style={{ padding: 12 }}>
          <div style={{ padding: 12, background: C.brandSoft, borderRadius: 12, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: -8, right: -8, fontSize: 36 }}>✨</div>
            <div style={{ fontFamily: C.display, fontSize: 14, fontWeight: 600, color: C.brandInk, lineHeight: 1.2, marginBottom: 4 }}>AI rubric mới</div>
            <div style={{ fontSize: 11.5, color: C.brandInk, opacity: 0.85, lineHeight: 1.4, marginBottom: 8 }}>Bản v3 chấm chính xác hơn 12% trên Úloha 4.</div>
            <button style={{ background: C.ink, color: '#fff', border: 'none', borderRadius: 999, padding: '6px 12px', fontSize: 11, fontWeight: 600, cursor: 'pointer', whiteSpace: 'nowrap' }}>Xem release notes</button>
          </div>
        </div>

        <div style={{ padding: '10px 14px 14px', borderTop: '1px solid ' + C.border, display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 30, height: 30, borderRadius: 999, background: '#0F3D3A', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: C.display, fontSize: 13, fontWeight: 600 }}>HT</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600 }}>Hà Trang</div>
            <div style={{ fontSize: 11, color: C.ink3 }}>Content editor</div>
          </div>
          <CIcon name="chev-d" size={14} color={C.ink3} />
        </div>
      </aside>

      {/* Main */}
      <main className="scrollarea" style={{ flex: 1, overflow: 'auto', display: 'flex', flexDirection: 'column' }}>
        <TopBar route={route} go={go} />
        <div style={{ flex: 1 }}>{children}</div>
      </main>
    </div>
  );
}

function TopBar({ route, go }) {
  const crumbs = [];
  if (route.page === 'dashboard') crumbs.push('Bảng điều khiển');
  if (route.page === 'courses') crumbs.push('Khóa học');
  if (route.page === 'course-detail') crumbs.push({ l: 'Khóa học', go: () => go('courses') }, 'Ôn thi A2 trvalý pobyt');
  if (route.page === 'editor') crumbs.push({ l: 'Khóa học', go: () => go('courses') }, { l: 'Tuần 3 · Nói', go: () => go('course-detail', { id: 'a2' }) }, 'Bài 4 · Khiếu nại tiền nhà');
  if (route.page === 'mock-list') crumbs.push('Mock test');
  if (route.page === 'mock') crumbs.push({ l: 'Mock test', go: () => go('mock-list') }, 'Mock 02 — Công việc & lịch hẹn');
  if (route.page === 'learners') crumbs.push('Học viên');
  if (route.page === 'learner-detail') crumbs.push({ l: 'Học viên', go: () => go('learners') }, 'Nguyễn Thị Mai');

  return (
    <div style={{ height: 56, padding: '0 24px', display: 'flex', alignItems: 'center', gap: 16, borderBottom: '1px solid ' + C.border, background: C.bg, position: 'sticky', top: 0, zIndex: 10 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: C.ink2 }}>
        {crumbs.map((c, i) => (
          <React.Fragment key={i}>
            {i > 0 && <CIcon name="chev-r" size={12} color={C.ink4} />}
            {typeof c === 'string'
              ? <span style={{ color: i === crumbs.length - 1 ? C.ink : C.ink2, fontWeight: i === crumbs.length - 1 ? 600 : 500 }}>{c}</span>
              : <button onClick={c.go} style={{ background: 'none', border: 'none', color: C.ink2, cursor: 'pointer', padding: 0, fontSize: 13, fontWeight: 500 }}>{c.l}</button>}
          </React.Fragment>
        ))}
      </div>
      <div style={{ flex: 1 }} />
      <div className="input-focus" style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 12px', background: C.surface, border: '1px solid ' + C.border, borderRadius: 9, width: 280, transition: 'all .15s' }}>
        <CIcon name="search" size={15} color={C.ink3} />
        <input placeholder="Tìm bài, học viên, đề thi..." style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontSize: 13, color: C.ink }} />
        <span style={{ fontSize: 10.5, color: C.ink4, fontFamily: C.mono, padding: '2px 5px', border: '1px solid ' + C.border, borderRadius: 4 }}>⌘K</span>
      </div>
      <button style={{ width: 34, height: 34, borderRadius: 9, background: 'transparent', border: '1px solid ' + C.border, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', position: 'relative' }}>
        <CIcon name="bell" size={16} color={C.ink2} />
        <span style={{ position: 'absolute', top: 7, right: 7, width: 6, height: 6, background: C.brand, borderRadius: 999 }} />
      </button>
      <button style={{ height: 34, padding: '0 14px', borderRadius: 9, background: C.ink, color: '#fff', border: 'none', display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 13, fontWeight: 600, boxShadow: '0 2px 0 #000', whiteSpace: 'nowrap', flexShrink: 0 }}>
        <CIcon name="plus" size={15} />
        Tạo mới
      </button>
    </div>
  );
}

// ─── Reusable bits ────────────────────────────────────────
function Btn({ children, variant = 'primary', size = 'md', icon, iconR, onClick, style = {} }) {
  const sizes = { sm: { h: 30, px: 12, fs: 12.5 }, md: { h: 36, px: 14, fs: 13 }, lg: { h: 44, px: 18, fs: 14 } };
  const v = {
    primary: { bg: C.brand, fg: '#fff', bd: 'none', sh: '0 2px 0 ' + C.brandDeep },
    inverse: { bg: C.ink, fg: '#fff', bd: 'none', sh: '0 2px 0 #000' },
    soft: { bg: C.brandSoft, fg: C.brandInk, bd: 'none', sh: 'none' },
    ghost: { bg: 'transparent', fg: C.ink, bd: '1px solid ' + C.borderStrong, sh: 'none' },
    danger: { bg: '#FBE4DE', fg: C.notInk, bd: 'none', sh: 'none' },
    text: { bg: 'transparent', fg: C.ink2, bd: 'none', sh: 'none' },
  }[variant];
  const s = sizes[size];
  return (
    <button onClick={onClick} style={{ height: s.h, padding: `0 ${s.px}px`, fontSize: s.fs, background: v.bg, color: v.fg, border: v.bd, boxShadow: v.sh, borderRadius: 9, fontWeight: 600, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6, cursor: 'pointer', whiteSpace: 'nowrap', flexShrink: 0, ...style }}>
      {icon && <CIcon name={icon} size={s.fs + 2} />}
      {children}
      {iconR && <CIcon name={iconR} size={s.fs + 2} />}
    </button>
  );
}

function Tag({ children, tone = 'neutral', size = 'md' }) {
  const tones = {
    neutral: { bg: 'rgba(20,18,14,0.06)', fg: C.ink2 },
    brand: { bg: C.brandSoft, fg: C.brandInk },
    ready: { bg: C.readyBg, fg: C.readyInk },
    almost: { bg: C.almostBg, fg: C.almostInk },
    needs: { bg: C.needsBg, fg: C.needsInk },
    not: { bg: C.notBg, fg: C.notInk },
    accent: { bg: C.accentSoft, fg: '#0F3D3A' },
  };
  const t = tones[tone];
  const small = size === 'sm';
  return <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: small ? '2px 7px' : '3px 9px', background: t.bg, color: t.fg, borderRadius: 6, fontSize: small ? 10.5 : 11.5, fontWeight: 600, letterSpacing: 0.1, whiteSpace: 'nowrap', flexShrink: 0 }}>{children}</span>;
}

function Card({ children, style = {}, padded = true, onClick }) {
  return <div onClick={onClick} style={{ background: C.surface, border: '1px solid ' + C.border, borderRadius: 14, padding: padded ? 18 : 0, boxShadow: C.shadowSm, cursor: onClick ? 'pointer' : 'default', ...style }}>{children}</div>;
}

function PageHeader({ title, subtitle, actions, eyebrow }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 16, padding: '24px 24px 18px' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        {eyebrow && <div style={{ fontSize: 11, fontWeight: 700, color: C.ink3, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 6, whiteSpace: 'nowrap' }}>{eyebrow}</div>}
        <div style={{ fontFamily: C.display, fontSize: 30, fontWeight: 600, letterSpacing: -0.6, lineHeight: 1.1, color: C.ink, fontVariationSettings: '"opsz" 144, "SOFT" 50', maxWidth: 720 }}>{title}</div>
        {subtitle && <div style={{ fontSize: 14, color: C.ink2, marginTop: 8, maxWidth: 600 }}>{subtitle}</div>}
      </div>
      {actions && <div style={{ display: 'flex', gap: 8 }}>{actions}</div>}
    </div>
  );
}

window.CMSShell = CMSShell;
window.Btn = Btn;
window.Tag = Tag;
window.Card = Card;
window.PageHeader = PageHeader;
