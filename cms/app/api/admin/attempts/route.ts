import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

export async function GET(request: NextRequest) {
  const qs = request.nextUrl.searchParams.toString();
  const url = `${apiBaseUrl}/v1/attempts${qs ? '?' + qs : ''}`;
  const response = await fetch(url, {
    cache: 'no-store',
    headers: { Authorization: `Bearer ${getAdminToken(request)}` },
  });
  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  });
}
