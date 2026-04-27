// Reusable UI primitives for A2 Mluveni Sprint

// ─── Readiness Badge ──────────────────────────────────────
function ReadinessBadge({ level = 'ready', size = 'md' }) {
  const map = {
    ready:  { label: 'READY',        bg: T.readyBg,  fg: T.readyInk,  dot: T.ready },
    almost: { label: 'ALMOST READY', bg: T.almostBg, fg: T.almostInk, dot: T.almost },
    needs:  { label: 'NEEDS WORK',   bg: T.needsBg,  fg: T.needsInk,  dot: T.needs },
    not:    { label: 'NOT READY',    bg: T.notBg,    fg: T.notInk,    dot: T.notReady },
  };
  const m = map[level];
  const small = size === 'sm';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: small ? 5 : 7,
      padding: small ? '3px 8px' : '5px 11px 5px 9px',
      background: m.bg, color: m.fg,
      borderRadius: 999, fontFamily: T.body,
      fontSize: small ? 10 : 11, fontWeight: 700,
      letterSpacing: 0.6,
    }}>
      <span style={{ width: small ? 5 : 6, height: small ? 5 : 6, borderRadius: 999, background: m.dot }} />
      {m.label}
    </span>
  );
}

// ─── Generic Pill / Tag ──────────────────────────────────
function Pill({ children, tone = 'neutral', size = 'md' }) {
  const tones = {
    neutral: { bg: 'rgba(40,32,20,0.06)', fg: T.ink2 },
    brand:   { bg: T.brandSoft, fg: T.brandInk },
    ready:   { bg: T.readyBg, fg: T.readyInk },
    needs:   { bg: T.needsBg, fg: T.needsInk },
    warm:    { bg: '#F1E8DA', fg: '#6E5530' },
    rec:     { bg: T.recBg, fg: '#7A1F14' },
  };
  const t = tones[tone];
  const small = size === 'sm';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: small ? '2px 7px' : '4px 10px',
      background: t.bg, color: t.fg,
      borderRadius: 999, fontFamily: T.body,
      fontSize: small ? 10.5 : 12, fontWeight: 600, letterSpacing: 0.1,
    }}>{children}</span>
  );
}

// ─── Button ───────────────────────────────────────────────
function Button({ children, variant = 'primary', size = 'md', onClick, disabled, full, style = {}, icon, iconRight }) {
  const sizes = {
    sm: { h: 38, px: 16, fs: 13.5, gap: 6 },
    md: { h: 50, px: 22, fs: 15, gap: 8 },
    lg: { h: 60, px: 26, fs: 16.5, gap: 10 },
  };
  const s = sizes[size];
  const variants = {
    primary:  { bg: T.brand, fg: '#fff', border: 'none', shadow: '0 2px 0 ' + T.brandDeep + ', 0 4px 14px rgba(255,106,20,0.25)' },
    inverse:  { bg: T.ink, fg: '#fff', border: 'none', shadow: '0 2px 0 #000' },
    soft:     { bg: T.brandSoft, fg: T.brandInk, border: 'none', shadow: 'none' },
    ghost:    { bg: 'transparent', fg: T.ink, border: '1.5px solid ' + T.borderStrong, shadow: 'none' },
    danger:   { bg: T.rec, fg: '#fff', border: 'none', shadow: '0 2px 0 #B83C00' },
    text:     { bg: 'transparent', fg: T.brand, border: 'none', shadow: 'none' },
  };
  const v = variants[variant];
  return (
    <button onClick={disabled ? undefined : onClick} disabled={disabled}
      style={{
        height: s.h, padding: `0 ${s.px}px`, fontSize: s.fs, gap: s.gap,
        background: v.bg, color: v.fg, border: v.border,
        boxShadow: v.shadow,
        borderRadius: 999, fontFamily: T.body, fontWeight: 700,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.45 : 1,
        width: full ? '100%' : undefined,
        letterSpacing: 0.1,
        transition: 'transform .12s ease, opacity .15s',
        ...style,
      }}>
      {icon && <Icon name={icon} size={s.fs + 3} />}
      {children}
      {iconRight && <Icon name={iconRight} size={s.fs + 3} />}
    </button>
  );
}

// ─── Card ─────────────────────────────────────────────────
function Card({ children, onClick, padded = true, style = {}, raised = false }) {
  return (
    <div onClick={onClick}
      style={{
        background: T.surface,
        borderRadius: T.r3,
        border: '1px solid ' + T.border,
        boxShadow: raised ? T.shadowMd : T.shadowSm,
        padding: padded ? 16 : 0,
        cursor: onClick ? 'pointer' : 'default',
        ...style,
      }}>{children}</div>
  );
}

// ─── Section title row ───────────────────────────────────
function SectionTitle({ eyebrow, title, action }) {
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', padding: '0 4px' }}>
      <div>
        {eyebrow && <div style={{ fontSize: 11, fontWeight: 700, color: T.ink3, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 4 }}>{eyebrow}</div>}
        <div style={{ fontFamily: T.display, fontSize: 24, fontWeight: 600, color: T.ink, letterSpacing: -0.4, fontVariationSettings: '"opsz" 144, "SOFT" 50' }}>{title}</div>
      </div>
      {action}
    </div>
  );
}

// ─── App nav bar (large title style) ─────────────────────
function AppNav({ title, leftAction, rightAction, large = true, subtitle }) {
  return (
    <div style={{ padding: large ? '8px 20px 16px' : '12px 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 32 }}>
        <div style={{ width: 32, display: 'flex' }}>{leftAction}</div>
        {!large && <div style={{ fontFamily: T.body, fontSize: 16, fontWeight: 700, color: T.ink }}>{title}</div>}
        <div style={{ width: 32, display: 'flex', justifyContent: 'flex-end' }}>{rightAction}</div>
      </div>
      {large && (
        <div>
          <div style={{ fontFamily: T.display, fontSize: 34, fontWeight: 600, color: T.ink, letterSpacing: -0.8, lineHeight: 1.05, fontVariationSettings: '"opsz" 144, "SOFT" 50' }}>{title}</div>
          {subtitle && <div style={{ fontSize: 14, color: T.ink2, marginTop: 6, lineHeight: 1.45 }}>{subtitle}</div>}
        </div>
      )}
    </div>
  );
}

// ─── Round icon button (nav circle) ──────────────────────
function NavIconBtn({ icon, onClick }) {
  return (
    <button onClick={onClick} style={{
      width: 34, height: 34, borderRadius: 999,
      background: 'rgba(40,32,20,0.05)', border: '1px solid ' + T.border,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      cursor: 'pointer', color: T.ink, padding: 0,
    }}>
      <Icon name={icon} size={16} />
    </button>
  );
}

// ─── Audio player bar ────────────────────────────────────
function AudioBar({ duration = 18, label = 'Bài ghi của bạn', dark = false }) {
  const [playing, setPlaying] = React.useState(false);
  const [pos, setPos] = React.useState(0);
  React.useEffect(() => {
    if (!playing) return;
    const id = setInterval(() => setPos(p => {
      if (p >= duration) { setPlaying(false); return 0; }
      return p + 0.1;
    }), 100);
    return () => clearInterval(id);
  }, [playing, duration]);
  const fmt = s => `${String(Math.floor(s/60)).padStart(1,'0')}:${String(Math.floor(s%60)).padStart(2,'0')}`;
  const fg = dark ? '#fff' : T.ink;
  const sub = dark ? 'rgba(255,255,255,0.6)' : T.ink3;
  const trackBg = dark ? 'rgba(255,255,255,0.15)' : 'rgba(40,32,20,0.08)';
  return (
    <div style={{
      background: dark ? 'rgba(255,255,255,0.06)' : T.surface,
      border: '1px solid ' + (dark ? 'rgba(255,255,255,0.1)' : T.border),
      borderRadius: T.r3, padding: 12,
      display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <button onClick={() => setPlaying(p => !p)} style={{
        width: 40, height: 40, borderRadius: 999, border: 'none',
        background: T.brand, color: '#fff', cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 0,
      }}>
        <Icon name={playing ? 'pause' : 'play'} size={18} />
      </button>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12, color: sub, marginBottom: 5 }}>{label}</div>
        <div style={{ position: 'relative', height: 4, background: trackBg, borderRadius: 999 }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${(pos/duration)*100}%`, background: T.brand, borderRadius: 999 }} />
        </div>
      </div>
      <div style={{ fontFamily: T.mono, fontSize: 12, color: sub, minWidth: 36, textAlign: 'right' }}>{fmt(pos)}</div>
    </div>
  );
}

// ─── Tab bar ─────────────────────────────────────────────
function TabBar({ active, onTab }) {
  const tabs = [
    { id: 'home', label: 'Học', icon: 'home' },
    { id: 'history', label: 'Lịch sử', icon: 'history' },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingBottom: 28, paddingTop: 8,
      background: 'rgba(244,241,234,0.85)',
      backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
      borderTop: '1px solid ' + T.border,
      display: 'flex', justifyContent: 'space-around', zIndex: 30,
    }}>
      {tabs.map(t => {
        const isActive = active === t.id;
        return (
          <button key={t.id} onClick={() => onTab(t.id)} style={{
            background: 'none', border: 'none', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            color: isActive ? T.brand : T.ink3, padding: '4px 24px',
          }}>
            <Icon name={t.icon} size={22} />
            <span style={{ fontSize: 10.5, fontWeight: 600, letterSpacing: 0.2 }}>{t.label}</span>
          </button>
        );
      })}
    </div>
  );
}

Object.assign(window, {
  ReadinessBadge, Pill, Button, Card, SectionTitle, AppNav, NavIconBtn, AudioBar, TabBar
});
