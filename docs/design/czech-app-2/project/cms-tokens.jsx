// CMS tokens — extends mobile palette with desktop densities
const C = {
  bg:        '#F5EDDD',
  panel:     '#FBF5E9',
  surface:   '#FFFFFF',
  surfaceAlt:'#FFF8EA',
  border:    'rgba(20,18,14,0.09)',
  borderStrong: 'rgba(20,18,14,0.16)',
  divider:   'rgba(20,18,14,0.07)',

  ink:       '#14110C',
  ink2:      '#4D4540',
  ink3:      '#857B72',
  ink4:      '#BCB2A6',

  brand:     '#FF6A14',
  brandDeep: '#E2530A',
  brandSoft: '#FFE5D2',
  brandInk:  '#5A2406',

  accent:    '#0F3D3A',
  accentSoft:'#D9E5E3',

  ready:'#1F8A4D', readyBg:'#E2F1E5', readyInk:'#0E4A28',
  almost:'#3060B8', almostBg:'#DEE9F7', almostInk:'#103A78',
  needs:'#C28012', needsBg:'#F8EAC9', needsInk:'#5C3A06',
  not:'#C03A28', notBg:'#F8DDD6', notInk:'#621D10',

  display: '"Fraunces", Georgia, serif',
  body:    '"Inter", -apple-system, system-ui, sans-serif',
  mono:    '"JetBrains Mono", ui-monospace, monospace',

  shadowSm: '0 1px 2px rgba(40,28,16,0.05)',
  shadowMd: '0 1px 2px rgba(40,28,16,0.04), 0 4px 12px rgba(40,28,16,0.06)',
  shadowLg: '0 4px 8px rgba(40,28,16,0.06), 0 16px 36px rgba(40,28,16,0.09)',
};

// Tiny icon (currentColor, 1.7 stroke)
function CIcon({ name, size = 18, color = 'currentColor', style = {} }) {
  const p = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: 1.7, strokeLinecap: 'round', strokeLinejoin: 'round', style };
  switch (name) {
    case 'home': return <svg {...p}><path d="M4 11l8-7 8 7v9a1 1 0 01-1 1h-4v-7h-6v7H5a1 1 0 01-1-1z"/></svg>;
    case 'book': return <svg {...p}><path d="M4 5a2 2 0 012-2h13v16H6a2 2 0 00-2 2zM6 19h13"/></svg>;
    case 'edit': return <svg {...p}><path d="M4 20l1-4L16 5l3 3L8 19l-4 1zM14 7l3 3"/></svg>;
    case 'trophy': return <svg {...p}><path d="M8 4h8v6a4 4 0 11-8 0zM5 5h3v3a2 2 0 11-3-2zM16 5h3a2 2 0 11-3 3zM10 17h4l-1 4h-2z"/></svg>;
    case 'users': return <svg {...p}><circle cx="9" cy="8" r="3.5"/><path d="M3 20a6 6 0 0112 0M16 11a3 3 0 100-6M21 20a5 5 0 00-4-5"/></svg>;
    case 'media': return <svg {...p}><rect x="3" y="4" width="18" height="14" rx="2"/><circle cx="9" cy="10" r="2"/><path d="M3 16l5-4 4 3 4-5 5 6"/></svg>;
    case 'gear': return <svg {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3 1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8 1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/></svg>;
    case 'plus': return <svg {...p}><path d="M12 5v14M5 12h14"/></svg>;
    case 'search': return <svg {...p}><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.5-4.5"/></svg>;
    case 'chev-r': return <svg {...p}><path d="M9 6l6 6-6 6"/></svg>;
    case 'chev-l': return <svg {...p}><path d="M15 6l-6 6 6 6"/></svg>;
    case 'chev-d': return <svg {...p}><path d="M6 9l6 6 6-6"/></svg>;
    case 'check': return <svg {...p}><path d="M5 12.5l4.5 4.5L19 7"/></svg>;
    case 'x': return <svg {...p}><path d="M6 6l12 12M18 6L6 18"/></svg>;
    case 'mic': return <svg {...p}><rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3"/></svg>;
    case 'play': return <svg {...p}><path d="M7 5l11 7-11 7V5z" fill={color}/></svg>;
    case 'pause': return <svg {...p}><rect x="6" y="5" width="4" height="14" fill={color}/><rect x="14" y="5" width="4" height="14" fill={color}/></svg>;
    case 'upload': return <svg {...p}><path d="M12 3v13M6 9l6-6 6 6M5 21h14"/></svg>;
    case 'sparkles': return <svg {...p}><path d="M12 3l1.8 4.5L18 9l-4.2 1.5L12 15l-1.8-4.5L6 9l4.2-1.5zM19 14l.8 2 2 .7-2 .8-.8 2-.8-2-2-.8 2-.7z"/></svg>;
    case 'eye': return <svg {...p}><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>;
    case 'globe': return <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/></svg>;
    case 'bell': return <svg {...p}><path d="M6 8a6 6 0 1112 0c0 7 3 7 3 9H3c0-2 3-2 3-9zM10 21a2 2 0 004 0"/></svg>;
    case 'dot': return <svg {...p} fill={color} stroke="none"><circle cx="12" cy="12" r="4"/></svg>;
    case 'drag': return <svg {...p}><circle cx="9" cy="6" r="1" fill={color}/><circle cx="15" cy="6" r="1" fill={color}/><circle cx="9" cy="12" r="1" fill={color}/><circle cx="15" cy="12" r="1" fill={color}/><circle cx="9" cy="18" r="1" fill={color}/><circle cx="15" cy="18" r="1" fill={color}/></svg>;
    case 'trash': return <svg {...p}><path d="M4 7h16M9 7V4h6v3M6 7l1 13a1 1 0 001 1h8a1 1 0 001-1l1-13M10 11v6M14 11v6"/></svg>;
    case 'copy': return <svg {...p}><rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a1 1 0 00-1-1H5a1 1 0 00-1 1v10a1 1 0 001 1h3"/></svg>;
    case 'flame': return <svg {...p}><path d="M12 22a6 6 0 006-6c0-3-2-5-3-7-1.5 2-3 2-3-1 0-2-1-4-2-5-1 4-5 6-5 11a7 7 0 007 8z"/></svg>;
    case 'flag': return <svg {...p}><path d="M5 21V4M5 4h12l-2 4 2 4H5"/></svg>;
    case 'clock': return <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case 'arrow-up': return <svg {...p}><path d="M12 19V5M5 12l7-7 7 7"/></svg>;
    case 'arrow-down': return <svg {...p}><path d="M12 5v14M5 12l7 7 7-7"/></svg>;
    case 'filter': return <svg {...p}><path d="M3 5h18l-7 9v6l-4-2v-4z"/></svg>;
    case 'list': return <svg {...p}><path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/></svg>;
    case 'grid': return <svg {...p}><rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/></svg>;
    case 'tag': return <svg {...p}><path d="M3 3h8l10 10-8 8L3 11z"/><circle cx="7" cy="7" r="1.5" fill={color}/></svg>;
    case 'save': return <svg {...p}><path d="M5 3h11l3 3v14a1 1 0 01-1 1H5a1 1 0 01-1-1V4a1 1 0 011-1z"/><path d="M8 3v5h7V3M8 21v-7h8v7"/></svg>;
    default: return <svg {...p}><circle cx="12" cy="12" r="9"/></svg>;
  }
}

const inputStyle = { width: '100%', padding: '10px 12px', fontSize: 13, color: C.ink, background: C.surface, border: '1px solid ' + C.border, borderRadius: 9, outline: 'none', resize: 'vertical', fontFamily: 'inherit', transition: 'all .15s' };

window.C = C;
window.CIcon = CIcon;
window.inputStyle = inputStyle;
