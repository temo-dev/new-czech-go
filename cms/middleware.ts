import { NextRequest, NextResponse } from 'next/server';

function unauthorizedResponse() {
  return new NextResponse('Authentication required.', {
    status: 401,
    headers: {
      'WWW-Authenticate': 'Basic realm="A2 Mluveni CMS"',
    },
  });
}

function parseBasicAuth(headerValue: string) {
  if (!headerValue.startsWith('Basic ')) {
    return null;
  }

  try {
    const decoded = atob(headerValue.slice('Basic '.length));
    const separatorIndex = decoded.indexOf(':');
    if (separatorIndex === -1) {
      return null;
    }

    return {
      username: decoded.slice(0, separatorIndex),
      password: decoded.slice(separatorIndex + 1),
    };
  } catch {
    return null;
  }
}

export function middleware(request: NextRequest) {
  const expectedUser = process.env.CMS_BASIC_AUTH_USER?.trim();
  const expectedPassword = process.env.CMS_BASIC_AUTH_PASSWORD?.trim();

  if (!expectedUser || !expectedPassword) {
    return NextResponse.next();
  }

  const credentials = parseBasicAuth(request.headers.get('authorization') ?? '');
  if (!credentials) {
    return unauthorizedResponse();
  }

  if (credentials.username !== expectedUser || credentials.password !== expectedPassword) {
    return unauthorizedResponse();
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api/healthz|_next/static|_next/image|favicon.ico).*)'],
};
