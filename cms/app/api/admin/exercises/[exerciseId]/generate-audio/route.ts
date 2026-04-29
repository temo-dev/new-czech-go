import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type RouteContext = {
  params: Promise<{
    exerciseId: string;
  }>;
};

export async function POST(request: NextRequest, context: RouteContext) {
  const { exerciseId } = await context.params;

  const response = await fetch(`${apiBaseUrl}/v1/admin/exercises/${exerciseId}/generate-audio`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
    },
  });

  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/json',
    },
  });
}
