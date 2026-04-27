// Icon set — 1.6 stroke, currentColor
function Icon({ name, size = 20, color = 'currentColor', style = {} }) {
  const s = { width: size, height: size, display: 'inline-block', verticalAlign: 'middle', flexShrink: 0, ...style };
  const sw = 1.7;
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: sw, strokeLinecap: 'round', strokeLinejoin: 'round', style: s };
  switch (name) {
    case 'mic': return <svg {...props}><rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3"/></svg>;
    case 'mic-fill': return <svg {...props} fill={color} stroke="none"><rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0014 0M12 18v3" stroke={color} strokeWidth={sw} strokeLinecap="round" fill="none"/></svg>;
    case 'play': return <svg {...props}><path d="M7 5l11 7-11 7V5z" fill={color}/></svg>;
    case 'pause': return <svg {...props}><rect x="6" y="5" width="4" height="14" fill={color}/><rect x="14" y="5" width="4" height="14" fill={color}/></svg>;
    case 'stop': return <svg {...props}><rect x="6" y="6" width="12" height="12" rx="2" fill={color}/></svg>;
    case 'chevron-right': return <svg {...props}><path d="M9 6l6 6-6 6"/></svg>;
    case 'chevron-left':  return <svg {...props}><path d="M15 6l-6 6 6 6"/></svg>;
    case 'chevron-down':  return <svg {...props}><path d="M6 9l6 6 6-6"/></svg>;
    case 'check':         return <svg {...props}><path d="M5 12.5l4.5 4.5L19 7"/></svg>;
    case 'x':             return <svg {...props}><path d="M6 6l12 12M18 6L6 18"/></svg>;
    case 'lock':          return <svg {...props}><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>;
    case 'clock':         return <svg {...props}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case 'history':       return <svg {...props}><path d="M3 12a9 9 0 109-9 9 9 0 00-7 3.4M3 4v4h4"/><path d="M12 7v5l3 2"/></svg>;
    case 'home':          return <svg {...props}><path d="M4 11l8-7 8 7v9a1 1 0 01-1 1h-4v-7h-6v7H5a1 1 0 01-1-1z"/></svg>;
    case 'sparkles':      return <svg {...props}><path d="M12 3l1.8 4.5L18 9l-4.2 1.5L12 15l-1.8-4.5L6 9l4.2-1.5zM19 14l.8 2 2 .7-2 .8-.8 2-.8-2-2-.8 2-.7z"/></svg>;
    case 'book':          return <svg {...props}><path d="M4 5a2 2 0 012-2h13v16H6a2 2 0 00-2 2zM6 19h13"/></svg>;
    case 'pencil':        return <svg {...props}><path d="M4 20l1-4L16 5l3 3L8 19l-4 1zM14 7l3 3"/></svg>;
    case 'ear':           return <svg {...props}><path d="M7 9a5 5 0 1110 0c0 3-3 4-3 6a2.5 2.5 0 11-5 0M9 13a3 3 0 015-2"/></svg>;
    case 'speech':        return <svg {...props}><path d="M4 5h16v11H10l-5 4v-4H4z"/></svg>;
    case 'grammar':       return <svg {...props}><path d="M5 4l4 12 1.5-4.5L15 10zM14 14l5 5M9 4h11"/></svg>;
    case 'word':          return <svg {...props}><path d="M5 4v16M5 4h10l4 4v12H5M14 4v5h5"/></svg>;
    case 'trophy':        return <svg {...props}><path d="M8 4h8v6a4 4 0 11-8 0zM5 5h3v3a2 2 0 11-3-2zM16 5h3a2 2 0 11-3 3zM10 17h4l-1 4h-2z"/></svg>;
    case 'flag':          return <svg {...props}><path d="M5 21V4M5 4h12l-2 4 2 4H5"/></svg>;
    case 'arrow-right':   return <svg {...props}><path d="M5 12h14M13 6l6 6-6 6"/></svg>;
    case 'arrow-left':    return <svg {...props}><path d="M19 12H5M11 6l-6 6 6 6"/></svg>;
    case 'plus':          return <svg {...props}><path d="M12 5v14M5 12h14"/></svg>;
    case 'dot':           return <svg {...props} fill={color} stroke="none"><circle cx="12" cy="12" r="4"/></svg>;
    case 'waveform':      return <svg {...props}><path d="M3 12h2M7 8v8M11 5v14M15 9v6M19 11v2M21 12h0"/></svg>;
    case 'redo':          return <svg {...props}><path d="M20 8v6h-6M20 14a8 8 0 10-3 6"/></svg>;
    case 'list':          return <svg {...props}><path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/></svg>;
    case 'spark':         return <svg {...props}><path d="M12 2v6M12 16v6M2 12h6M16 12h6M5 5l4 4M15 15l4 4M5 19l4-4M15 9l4-4"/></svg>;
    case 'cards':         return <svg {...props}><rect x="3" y="6" width="14" height="14" rx="2"/><path d="M7 6V4a1 1 0 011-1h12a1 1 0 011 1v14a1 1 0 01-1 1h-2"/></svg>;
    default: return <svg {...props}><circle cx="12" cy="12" r="9"/></svg>;
  }
}
window.Icon = Icon;
