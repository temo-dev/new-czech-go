import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

export async function GET(request: NextRequest) {
  const res = await fetch(`${apiBaseUrl}/v1/admin/content-health`, {
    method: 'GET',
    cache: 'no-store',
    headers: { Authorization: `Bearer ${getAdminToken(request)}` },
  });
  return new Response(await res.text(), {
    status: res.status,
    headers: { 'Content-Type': res.headers.get('Content-Type') ?? 'application/json' },
  });
}
