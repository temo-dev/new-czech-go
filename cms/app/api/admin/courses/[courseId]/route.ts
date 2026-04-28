import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';
type Ctx = { params: Promise<{ courseId: string }> };
async function proxy(method: 'GET' | 'PATCH' | 'DELETE', req: NextRequest, ctx: Ctx) {
  const { courseId } = await ctx.params;
  const body = method === 'PATCH' ? await req.text() : undefined;
  const res = await fetch(`${apiBaseUrl}/v1/admin/courses/${courseId}`, { method, cache: 'no-store', headers: { Authorization: `Bearer ${getAdminToken(req)}`, ...(body ? { 'Content-Type': 'application/json' } : {}) }, body });
  return new Response(await res.text(), { status: res.status, headers: { 'Content-Type': res.headers.get('Content-Type') ?? 'application/json' } });
}
export async function GET(req: NextRequest, ctx: Ctx) { return proxy('GET', req, ctx); }
export async function PATCH(req: NextRequest, ctx: Ctx) { return proxy('PATCH', req, ctx); }
export async function DELETE(req: NextRequest, ctx: Ctx) { return proxy('DELETE', req, ctx); }
