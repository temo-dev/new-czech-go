'use client';

/**
 * Wrapper around fetch for CMS API proxy calls.
 * Automatically redirects to /api/auth/logout (which clears cookie + goes to /login)
 * when the backend returns 401 — handles stale sessions after backend restarts.
 */
export async function adminFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const response = await fetch(input, { cache: 'no-store', ...init });
  if (response.status === 401) {
    window.location.href = '/api/auth/logout';
    // Return a never-settling promise so callers don't process the 401 body
    return new Promise(() => {});
  }
  return response;
}
