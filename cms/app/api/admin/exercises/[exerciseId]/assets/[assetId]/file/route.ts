import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type RouteContext = {
  params: Promise<{
    exerciseId: string;
    assetId: string;
  }>;
};

export async function GET(request: NextRequest, context: RouteContext) {
  const { exerciseId, assetId } = await context.params;

  const response = await fetch(`${apiBaseUrl}/v1/admin/exercises/${exerciseId}/assets/${assetId}/file`, {
    method: 'GET',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
    },
    redirect: 'follow',
  });

  return new Response(response.body, {
    status: response.status,
    headers: {
      'Content-Type': response.headers.get('Content-Type') ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
    },
  });
}
