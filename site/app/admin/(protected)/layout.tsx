import Image from 'next/image';
import Link from 'next/link';
import type { ReactNode } from 'react';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { adminTables } from '@/lib/admin/schema';
import { logoutAction } from '../actions';

export default async function ProtectedAdminLayout({ children }: { children: ReactNode }) {
  const admin = await requireSuperAdmin();

  return (
    <div className="adminShell">
      <aside className="adminSidebar">
        <Link href="/admin" className="adminBrand">
          <Image src="/link-logo.png" alt="Link" width={46} height={46} />
          <span><strong>Link Control</strong><small>إدارة المنظومة</small></span>
        </Link>
        <nav>
          <Link href="/admin" className="navPrimary">◫ نظرة عامة</Link>
          <p>قاعدة البيانات</p>
          {Object.entries(adminTables).map(([key, table]) => (
            <Link href={`/admin/data/${key}`} key={key}>{table.label}</Link>
          ))}
        </nav>
        <form action={logoutAction} className="logoutForm"><button type="submit">تسجيل الخروج</button></form>
      </aside>
      <div className="adminMain">
        <header className="adminTopbar">
          <div><span className="liveDot" /> بيانات مباشرة من الإنتاج</div>
          <div className="adminIdentity"><strong>{admin.fullName}</strong><small>{admin.email}</small></div>
        </header>
        {children}
      </div>
    </div>
  );
}

