import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

async function proxyToBackend(method: 'GET' | 'POST', request: NextRequest) {
  const body = method === 'POST' ? await request.text() : undefined;
  const response = await fetch(`${apiBaseUrl}/v1/admin/mock-tests`, {
    method,
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
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

export async function GET(request: NextRequest) {
  return proxyToBackend('GET', request);
}

export async function POST(request: NextRequest) {
  return proxyToBackend('POST', request);
}
