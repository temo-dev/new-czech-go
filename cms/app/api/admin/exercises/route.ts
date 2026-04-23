import { NextRequest } from 'next/server';

const apiBaseUrl = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';
const adminToken = process.env.CMS_ADMIN_TOKEN ?? process.env.NEXT_PUBLIC_ADMIN_TOKEN ?? 'dev-admin-token';

async function proxyToBackend(method: 'GET' | 'POST', request: NextRequest) {
  const body = method === 'POST' ? await request.text() : undefined;
  const response = await fetch(`${apiBaseUrl}/v1/admin/exercises`, {
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

export async function GET(request: NextRequest) {
  return proxyToBackend('GET', request);
}

export async function POST(request: NextRequest) {
  return proxyToBackend('POST', request);
}
