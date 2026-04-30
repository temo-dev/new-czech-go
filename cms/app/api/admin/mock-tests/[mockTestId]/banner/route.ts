import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type RouteContext = { params: Promise<{ mockTestId: string }> };

export async function POST(request: NextRequest, context: RouteContext) {
  const { mockTestId } = await context.params;
  const form = await request.formData();
  const file = form.get('file');

  if (!(file instanceof File)) {
    return Response.json(
      { error: { code: 'validation_error', message: 'file field is required.', retryable: false, details: {} } },
      { status: 400 },
    );
  }

  const formData = new FormData();
  formData.append('file', new Blob([await file.arrayBuffer()], { type: file.type }), file.name);

  const response = await fetch(`${apiBaseUrl}/v1/admin/mock-tests/${mockTestId}/banner`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${getAdminToken(request)}` },
    body: formData,
  });

  const payload = await response.json();
  return Response.json(payload, { status: response.status });
}

export async function DELETE(request: NextRequest, context: RouteContext) {
  const { mockTestId } = await context.params;
  const response = await fetch(`${apiBaseUrl}/v1/admin/mock-tests/${mockTestId}/banner`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${getAdminToken(request)}` },
  });
  const payload = await response.json();
  return Response.json(payload, { status: response.status });
}
