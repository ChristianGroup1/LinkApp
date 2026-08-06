import type { ReactNode } from 'react';
import './admin.css';

export const dynamic = 'force-dynamic';

export default function AdminRootLayout({ children }: { children: ReactNode }) {
  return <div className="adminRoot">{children}</div>;
}

