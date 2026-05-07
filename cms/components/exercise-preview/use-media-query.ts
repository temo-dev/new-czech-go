'use client';

import { useEffect, useState } from 'react';

// V23 Phase C1 — minimal media query hook. SSR-safe: defaults to
// false on the server (mobile-first) and updates after mount via
// matchMedia. Callers should not gate critical rendering on this
// hook during the very first paint — the preview pane is non-
// critical and re-mounts cleanly.
export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);
  useEffect(() => {
    if (typeof window === 'undefined' || !window.matchMedia) return;
    const mql = window.matchMedia(query);
    setMatches(mql.matches);
    const handler = (e: MediaQueryListEvent) => setMatches(e.matches);
    mql.addEventListener('change', handler);
    return () => mql.removeEventListener('change', handler);
  }, [query]);
  return matches;
}
