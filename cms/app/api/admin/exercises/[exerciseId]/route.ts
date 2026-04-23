import { NextRequest } from 'next/server';

const apiBaseUrl = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';
const adminToken = process.env.CMS_ADMIN_TOKEN ?? process.env.NEXT_PUBLIC_ADMIN_TOKEN ?? 'dev-admin-token';

type RouteContext = {
  params: Promise<{
    exerciseId: string;
  }>;
};

async function proxyToBackend(
  method: 'GET' | 'PATCH' | 'DELETE',
  request: NextRequest,
  context: RouteContext,
) {
  const { exerciseId } = await context.params;
  const body = method === 'PATCH' ? await request.text() : undefined;
  const response = await fetch(`${apiBaseUrl}/v1/admin/exercises/${exerciseId}`, {
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
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  });
}

export async function GET(request: NextRequest, context: RouteContext) {
  return proxyToBackend('GET', request, context);
}

export async function PATCH(request: NextRequest, context: RouteContext) {
  return proxyToBackend('PATCH', request, context);
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  return proxyToBackend('DELETE', request, context);
}
