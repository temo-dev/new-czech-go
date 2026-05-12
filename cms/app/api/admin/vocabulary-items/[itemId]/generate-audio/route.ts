import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

// V37 — proxies the admin Polly-generate call to the backend so the CMS
// browser bundle keeps the admin token server-side.

type RouteContext = { params: Promise<{ itemId: string }> };

export async function POST(request: NextRequest, context: RouteContext) {
  const { itemId } = await context.params;

  const response = await fetch(`${apiBaseUrl}/v1/admin/vocabulary-items/${itemId}/generate-audio`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
  });

  const payload = await response.json();
  return Response.json(payload, { status: response.status });
}
