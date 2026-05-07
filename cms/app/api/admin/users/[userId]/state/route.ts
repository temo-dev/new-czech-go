import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type Ctx = { params: Promise<{ userId: string }> };

export async function GET(request: NextRequest, ctx: Ctx) {
  const { userId } = await ctx.params;
  const res = await fetch(`${apiBaseUrl}/v1/admin/users/${encodeURIComponent(userId)}/state`, {
    method: 'GET',
    cache: 'no-store',
    headers: { Authorization: `Bearer ${getAdminToken(request)}` },
  });
  return new Response(await res.text(), {
    status: res.status,
    headers: { 'Content-Type': res.headers.get('Content-Type') ?? 'application/json' },
  });
}
