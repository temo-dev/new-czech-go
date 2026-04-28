import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const loginUrl = new URL('/login', request.url);
  const response = NextResponse.redirect(loginUrl);
  response.cookies.set('admin_token', '', { maxAge: 0, path: '/' });
  return response;
}
