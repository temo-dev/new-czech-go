import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

// Proxy GET /api/media/file?key=... → backend GET /v1/media/file?key=...
// Used by CMS to preview course banners and other media assets.
export async function GET(request: NextRequest) {
  const key = request.nextUrl.searchParams.get('key');
  if (!key) return new Response('Missing key', { status: 400 });

  const response = await fetch(`${apiBaseUrl}/v1/media/file?key=${encodeURIComponent(key)}`, {
    headers: { Authorization: `Bearer ${getAdminToken(request)}` },
  });

  if (!response.ok) return new Response(null, { status: response.status });

  const contentType = response.headers.get('content-type') ?? 'application/octet-stream';
  const body = await response.arrayBuffer();
  return new Response(body, {
    headers: {
      'Content-Type': contentType,
      'Cache-Control': 'public, max-age=86400',
    },
  });
}
