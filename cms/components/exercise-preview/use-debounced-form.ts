'use client';

import { useEffect, useState } from 'react';

// V23 Phase C3 — debounce form state so the preview pane does not
// re-render on every keystroke. 200 ms keeps the preview feeling
// live without thrashing renderers when the admin types in a long
// prompt.
export function useDebouncedForm<T>(form: T, delayMs: number = 200): T {
  const [debounced, setDebounced] = useState(form);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(form), delayMs);
    return () => clearTimeout(id);
  }, [form, delayMs]);
  return debounced;
}
