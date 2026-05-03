import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

export async function POST(request: NextRequest) {
  const body = await request.text();
  const response = await fetch(`${apiBaseUrl}/v1/admin/ai/set-banner`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
      'Content-Type': 'application/json',
    },
    body,
  });
  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: { 'Content-Type': 'application/json' },
  });
}
