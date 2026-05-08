import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

// V24 reading-draft generator proxy. Forwards the admin POST request to the
// backend and streams the response back. The backend handler enforces
// validation, rate-limiting, and Czech-quality schema checks.
export async function POST(req: NextRequest) {
  const body = await req.text();
  const url = `${apiBaseUrl}/v1/admin/exercises/generate-draft`;
  const res = await fetch(url, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(req)}`,
      'Content-Type': 'application/json',
    },
    body,
  });
  return new Response(await res.text(), {
    status: res.status,
    headers: { 'Content-Type': 'application/json' },
  });
}
