import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type Ctx = { params: Promise<{ userId: string }> };

export async function POST(request: NextRequest, ctx: Ctx) {
  const { userId } = await ctx.params;
  const res = await fetch(`${apiBaseUrl}/v1/admin/users/${encodeURIComponent(userId)}/usage/reset`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
    },
  });
  if (res.status === 204) {
    return new Response(null, { status: 204 });
  }
  return new Response(await res.text(), {
    status: res.status,
    headers: { 'Content-Type': res.headers.get('Content-Type') ?? 'application/json' },
  });
}
