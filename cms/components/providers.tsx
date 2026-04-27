'use client';

import { LocaleProvider } from '../lib/i18n';
import { ReactNode } from 'react';

export function Providers({ children }: { children: ReactNode }) {
  return <LocaleProvider>{children}</LocaleProvider>;
}
