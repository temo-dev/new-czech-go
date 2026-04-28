import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type Ctx = { params: Promise<{ setId: string }> };

async function proxy(method: string, req: NextRequest, ctx: Ctx) {
  const { setId } = await ctx.params;
  const body = (method === 'PATCH' || method === 'POST') ? await req.text() : undefined;
  const qs = req.nextUrl.searchParams.toString();
  const url = `${apiBaseUrl}/v1/admin/vocabulary-sets/${setId}${qs ? '?' + qs : ''}`;
  const res = await fetch(url, {
    method, cache: 'no-store',
    headers: { Authorization: `Bearer ${getAdminToken(req)}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body,
  });
  return new Response(await res.text(), { status: res.status, headers: { 'Content-Type': 'application/json' } });
}

export async function GET(req: NextRequest, ctx: Ctx) { return proxy('GET', req, ctx); }
export async function PATCH(req: NextRequest, ctx: Ctx) { return proxy('PATCH', req, ctx); }
export async function DELETE(req: NextRequest, ctx: Ctx) { return proxy('DELETE', req, ctx); }
