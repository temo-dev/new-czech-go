import { NextRequest } from 'next/server';

/**
 * Returns the admin bearer token for backend API calls.
 * Priority: HTTP-only cookie set at login > CMS_ADMIN_TOKEN env var > 'dev-admin-token' fallback.
 */
export function getAdminToken(request: NextRequest): string {
  return (
    request.cookies.get('admin_token')?.value ??
    process.env.CMS_ADMIN_TOKEN ??
    'dev-admin-token'
  );
}

export const apiBaseUrl =
  process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';
