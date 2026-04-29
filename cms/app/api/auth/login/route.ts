import { NextRequest, NextResponse } from 'next/server';

const apiBaseUrl =
  process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080';

export async function POST(request: NextRequest) {
  const body = await request.text();

  let backendRes: Response;
  try {
    backendRes = await fetch(`${apiBaseUrl}/v1/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      cache: 'no-store',
    });
  } catch {
    return NextResponse.json({ error: 'Backend unreachable' }, { status: 502 });
  }

  if (!backendRes.ok) {
    const text = await backendRes.text();
    return new NextResponse(text, { status: backendRes.status });
  }

  const data = await backendRes.json();
  const token: string = data?.data?.access_token;
  if (!token) {
    return NextResponse.json({ error: 'No token in backend response' }, { status: 502 });
  }

  const response = NextResponse.json({ ok: true });
  response.cookies.set('admin_token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 86400,
    path: '/',
  });
  return response;
}
