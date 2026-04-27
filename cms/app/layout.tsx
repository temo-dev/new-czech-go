import './globals.css';
import type { Metadata } from 'next';
import { ReactNode } from 'react';
import { CmsSidebar } from '../components/cms-sidebar';

export const metadata: Metadata = {
  title: 'A2 Mluveni CMS',
  description: 'Thin content management surface for Czech speaking practice.'
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, display: 'flex', minHeight: '100vh', background: 'var(--bg)' }}>
        <CmsSidebar />
        <main style={{ flex: 1, minWidth: 0, padding: 32, overflowY: 'auto' }}>
          {children}
        </main>
      </body>
    </html>
  );
}
