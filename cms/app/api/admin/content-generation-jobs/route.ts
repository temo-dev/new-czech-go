import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

async function proxy(method: 'GET' | 'POST', req: NextRequest) {
  const body = method === 'POST' ? await req.text() : undefined;
  const qs = req.nextUrl.searchParams.toString();
  const url = `${apiBaseUrl}/v1/admin/content-generation-jobs${qs ? '?' + qs : ''}`;
  const res = await fetch(url, {
    method, cache: 'no-store',
    headers: { Authorization: `Bearer ${getAdminToken(req)}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body,
  });
  return new Response(await res.text(), { status: res.status, headers: { 'Content-Type': 'application/json' } });
}

export async function GET(req: NextRequest) { return proxy('GET', req); }
export async function POST(req: NextRequest) { return proxy('POST', req); }
