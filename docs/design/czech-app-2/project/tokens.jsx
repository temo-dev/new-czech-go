// Design tokens — Babbel-inspired (orange + cream + Fraunces)

const T = {
  // Backgrounds — cream / Babbel beige
  bg:        '#FBF3E7',     // app background — warm cream
  surface:   '#FFFFFF',     // cards
  surfaceAlt:'#FFF8EA',     // subtle alt
  border:    'rgba(20,18,14,0.08)',
  borderStrong: 'rgba(20,18,14,0.16)',
  divider:   'rgba(20,18,14,0.07)',

  // Ink — near-black warm
  ink:       '#14110C',     // primary text
  ink2:      '#4D4540',     // secondary
  ink3:      '#857B72',     // tertiary
  ink4:      '#BCB2A6',     // disabled / placeholder

  // Brand — Babbel orange
  brand:     '#FF6A14',
  brandDeep: '#E2530A',
  brandSoft: '#FFE5D2',
  brandInk:  '#5A2406',

  // Secondary accent — deep teal (Babbel uses dark accents in marketing)
  accent:    '#0F3D3A',
  accentSoft:'#D9E5E3',

  // Readiness — kept semantic but warmed
  ready:     '#1F8A4D',
  readyBg:   '#E2F1E5',
  readyInk:  '#0E4A28',

  almost:    '#3060B8',
  almostBg:  '#DEE9F7',
  almostInk: '#103A78',

  needs:    '#C28012',
  needsBg:  '#F8EAC9',
  needsInk: '#5C3A06',

  notReady:  '#C03A28',
  notBg:     '#F8DDD6',
  notInk:    '#621D10',

  // Functional
  rec:      '#E2530A',
  recBg:    '#FFE0CD',
  pass:     '#1F8A4D',
  fail:     '#C03A28',

  // Type families — Babbel "Feature" → Fraunces (closest free)
  display: '"Fraunces", "Playfair Display", Georgia, serif',
  body:    '"Inter", -apple-system, system-ui, sans-serif',
  mono:    '"JetBrains Mono", ui-monospace, monospace',

  // Radii — Babbel uses generous rounding
  r1: 10, r2: 14, r3: 18, r4: 24, r5: 32,

  // Shadows — soft, warm
  shadowSm: '0 1px 2px rgba(40,28,16,0.05), 0 1px 1px rgba(40,28,16,0.03)',
  shadowMd: '0 2px 4px rgba(40,28,16,0.05), 0 6px 16px rgba(40,28,16,0.06)',
  shadowLg: '0 4px 8px rgba(40,28,16,0.06), 0 16px 36px rgba(40,28,16,0.09)',
};

window.T = T;
