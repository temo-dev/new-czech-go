import { NextRequest } from 'next/server';

const apiBaseUrl = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';
const adminToken = process.env.CMS_ADMIN_TOKEN ?? process.env.NEXT_PUBLIC_ADMIN_TOKEN ?? 'dev-admin-token';

type RouteContext = {
  params: Promise<{
    exerciseId: string;
  }>;
};

export async function POST(request: NextRequest, context: RouteContext) {
  const { exerciseId } = await context.params;
  const body = await request.text();

  const response = await fetch(`${apiBaseUrl}/v1/admin/exercises/${exerciseId}/assets/upload-url`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${adminToken}`,
      'Content-Type': 'application/json',
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
