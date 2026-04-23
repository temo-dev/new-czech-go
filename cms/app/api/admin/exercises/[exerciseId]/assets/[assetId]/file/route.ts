import { NextRequest } from 'next/server';

const apiBaseUrl = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';
const adminToken = process.env.CMS_ADMIN_TOKEN ?? process.env.NEXT_PUBLIC_ADMIN_TOKEN ?? 'dev-admin-token';

type RouteContext = {
  params: Promise<{
    exerciseId: string;
    assetId: string;
  }>;
};

export async function GET(_request: NextRequest, context: RouteContext) {
  const { exerciseId, assetId } = await context.params;

  const response = await fetch(`${apiBaseUrl}/v1/admin/exercises/${exerciseId}/assets/${assetId}/file`, {
    method: 'GET',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${adminToken}`,
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
