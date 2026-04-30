import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type RouteContext = { params: Promise<{ exerciseId: string; assetId: string }> };

export async function DELETE(request: NextRequest, context: RouteContext) {
  const { exerciseId, assetId } = await context.params;
  const response = await fetch(
    `${apiBaseUrl}/v1/admin/exercises/${exerciseId}/assets/${assetId}`,
    {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${getAdminToken(request)}` },
    },
  );
  const payload = await response.json();
  return Response.json(payload, { status: response.status });
}
