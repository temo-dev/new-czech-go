import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type RouteContext = {
  params: Promise<{
    exerciseId: string;
    idx: string;
  }>;
};

// V18 — proxy for per-sentence dictation audio generation/deletion.
// Backend route shape: /v1/admin/exercises/:id/dictation/sentences/:idx/audio
// POST body: {"text": "<Czech sentence>"}; backend caps at 250 runes / 1KB.
// DELETE has no body; backend removes the row + best-effort blob.

export async function POST(request: NextRequest, context: RouteContext) {
  const { exerciseId, idx } = await context.params;
  const body = await request.text();

  const response = await fetch(
    `${apiBaseUrl}/v1/admin/exercises/${exerciseId}/dictation/sentences/${idx}/audio`,
    {
      method: 'POST',
      cache: 'no-store',
      headers: {
        Authorization: `Bearer ${getAdminToken(request)}`,
        'Content-Type': 'application/json',
      },
      body,
    }
  );

  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  });
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const { exerciseId, idx } = await context.params;

  const response = await fetch(
    `${apiBaseUrl}/v1/admin/exercises/${exerciseId}/dictation/sentences/${idx}/audio`,
    {
      method: 'DELETE',
      cache: 'no-store',
      headers: {
        Authorization: `Bearer ${getAdminToken(request)}`,
      },
    }
  );

  if (response.status === 204) {
    return new Response(null, { status: 204 });
  }
  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  });
}
