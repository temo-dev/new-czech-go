import { NextRequest } from 'next/server';

const apiBaseUrl = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';
const adminToken = process.env.CMS_ADMIN_TOKEN ?? process.env.NEXT_PUBLIC_ADMIN_TOKEN ?? 'dev-admin-token';

type RouteContext = { params: Promise<{ mockTestId: string }> };

async function proxyToBackend(method: 'GET' | 'PATCH' | 'DELETE', request: NextRequest, context: RouteContext) {
  const { mockTestId } = await context.params;
  const body = method === 'PATCH' ? await request.text() : undefined;
  const response = await fetch(`${apiBaseUrl}/v1/admin/mock-tests/${mockTestId}`, {
    method,
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${adminToken}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body,
  });
  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: { 'Content-Type': response.headers.get('Content-Type') ?? 'application/json' },
  });
}

export async function GET(req: NextRequest, ctx: RouteContext) { return proxyToBackend('GET', req, ctx); }
export async function PATCH(req: NextRequest, ctx: RouteContext) { return proxyToBackend('PATCH', req, ctx); }
export async function DELETE(req: NextRequest, ctx: RouteContext) { return proxyToBackend('DELETE', req, ctx); }
