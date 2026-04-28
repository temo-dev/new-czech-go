import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type Ctx = { params: Promise<{ jobId: string }> };

async function proxy(method: string, req: NextRequest, ctx: Ctx) {
  const { jobId } = await ctx.params;
  const body = (method === 'PATCH' || method === 'POST') ? await req.text() : undefined;
  // Sub-actions like /draft, /publish, /reject come via searchParams action
  const action = req.nextUrl.searchParams.get('action');
  const suffix = action ? `/${action}` : '';
  const url = `${apiBaseUrl}/v1/admin/content-generation-jobs/${jobId}${suffix}`;
  const res = await fetch(url, {
    method, cache: 'no-store',
    headers: { Authorization: `Bearer ${getAdminToken(req)}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body,
  });
  return new Response(await res.text(), { status: res.status, headers: { 'Content-Type': 'application/json' } });
}

export async function GET(req: NextRequest, ctx: Ctx) { return proxy('GET', req, ctx); }
export async function POST(req: NextRequest, ctx: Ctx) { return proxy('POST', req, ctx); }
export async function PATCH(req: NextRequest, ctx: Ctx) { return proxy('PATCH', req, ctx); }
