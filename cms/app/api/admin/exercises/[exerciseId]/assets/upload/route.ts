import { NextRequest } from 'next/server';
import { getAdminToken, apiBaseUrl } from '@/lib/auth';

type RouteContext = {
  params: Promise<{
    exerciseId: string;
  }>;
};

export async function POST(request: NextRequest, context: RouteContext) {
  const { exerciseId } = await context.params;
  const form = await request.formData();
  const file = form.get('file');
  const assetKind = String(form.get('asset_kind') ?? 'image').trim() || 'image';
  const sequenceNo = Number(form.get('sequence_no') ?? '0');

  if (!(file instanceof File)) {
    return Response.json(
      {
        error: {
          code: 'validation_error',
          message: 'A file is required.',
          retryable: false,
          details: {},
        },
      },
      { status: 400 },
    );
  }

  const mimeType = file.type || 'application/octet-stream';

  const uploadTargetResponse = await fetch(`${apiBaseUrl}/v1/admin/exercises/${exerciseId}/assets/upload-url`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      asset_kind: assetKind,
      mime_type: mimeType,
    }),
  });

  const uploadTargetPayload = await uploadTargetResponse.json();
  if (!uploadTargetResponse.ok) {
    return Response.json(uploadTargetPayload, { status: uploadTargetResponse.status });
  }

  const upload = uploadTargetPayload.data.upload as {
    url: string;
    headers?: Record<string, string>;
    storage_key: string;
  };
  const asset = uploadTargetPayload.data.asset as {
    id: string;
  };

  const uploadHeaders = new Headers(upload.headers ?? {});
  if (!uploadHeaders.has('Content-Type')) {
    uploadHeaders.set('Content-Type', mimeType);
  }
  if (upload.url.startsWith(apiBaseUrl) && !uploadHeaders.has('Authorization')) {
    uploadHeaders.set('Authorization', `Bearer ${getAdminToken(request)}`);
  }

  const uploadResponse = await fetch(upload.url, {
    method: 'PUT',
    headers: uploadHeaders,
    body: Buffer.from(await file.arrayBuffer()),
  });

  if (!uploadResponse.ok) {
    return Response.json(
      {
        error: {
          code: 'upload_failed',
          message: 'Could not upload the selected asset.',
          retryable: true,
          details: {},
        },
      },
      { status: uploadResponse.status },
    );
  }

  const registerResponse = await fetch(`${apiBaseUrl}/v1/admin/exercises/${exerciseId}/assets`, {
    method: 'POST',
    cache: 'no-store',
    headers: {
      Authorization: `Bearer ${getAdminToken(request)}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      id: asset.id,
      asset_kind: assetKind,
      storage_key: upload.storage_key,
      mime_type: mimeType,
      sequence_no: Number.isFinite(sequenceNo) ? sequenceNo : 0,
    }),
  });

  const registerPayload = await registerResponse.json();
  return Response.json(registerPayload, { status: registerResponse.status });
}
