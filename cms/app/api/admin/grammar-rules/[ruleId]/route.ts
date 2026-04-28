import { NextRequest } from 'next/server';

const apiBaseUrl = process.env.API_BASE_URL ?? 'http://localhost:8080';
const adminToken = process.env.CMS_ADMIN_TOKEN ?? 'dev-admin-token';

type Ctx = { params: Promise<{ ruleId: string }> };

async function proxy(method: string, req: NextRequest, ctx: Ctx) {
  const { ruleId } = await ctx.params;
  const body = (method === 'PATCH') ? await req.text() : undefined;
  const url = `${apiBaseUrl}/v1/admin/grammar-rules/${ruleId}`;
  const res = await fetch(url, {
    method, cache: 'no-store',
    headers: { Authorization: `Bearer ${adminToken}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body,
  });
  return new Response(await res.text(), { status: res.status, headers: { 'Content-Type': 'application/json' } });
}

export async function GET(req: NextRequest, ctx: Ctx) { return proxy('GET', req, ctx); }
export async function PATCH(req: NextRequest, ctx: Ctx) { return proxy('PATCH', req, ctx); }
export async function DELETE(req: NextRequest, ctx: Ctx) { return proxy('DELETE', req, ctx); }
