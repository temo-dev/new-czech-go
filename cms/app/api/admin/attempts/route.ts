import { NextRequest } from 'next/server';

const apiBaseUrl =
  process.env.API_BASE_URL ??
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  'http://localhost:8080';
const adminToken =
  process.env.CMS_ADMIN_TOKEN ??
  process.env.NEXT_PUBLIC_ADMIN_TOKEN ??
  'dev-admin-token';

export async function GET(request: NextRequest) {
  const qs = request.nextUrl.searchParams.toString();
  const url = `${apiBaseUrl}/v1/attempts${qs ? '?' + qs : ''}`;
  const response = await fetch(url, {
    cache: 'no-store',
    headers: { Authorization: `Bearer ${adminToken}` },
  });
  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  });
}
