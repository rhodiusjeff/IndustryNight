import type { NextRequest } from 'next/server';

export async function GET(req: NextRequest, context: { params: { path: string[] } }) {
  return proxyRequest(req, context.params.path, 'GET');
}

export async function POST(req: NextRequest, context: { params: { path: string[] } }) {
  return proxyRequest(req, context.params.path, 'POST');
}

export async function PATCH(req: NextRequest, context: { params: { path: string[] } }) {
  return proxyRequest(req, context.params.path, 'PATCH');
}

export async function PUT(req: NextRequest, context: { params: { path: string[] } }) {
  return proxyRequest(req, context.params.path, 'PUT');
}

export async function DELETE(req: NextRequest, context: { params: { path: string[] } }) {
  return proxyRequest(req, context.params.path, 'DELETE');
}

async function proxyRequest(req: NextRequest, pathSegments: string[], method: string) {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) {
    return new Response(JSON.stringify({ error: 'NEXT_PUBLIC_API_URL is not configured' }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    });
  }

  const path = pathSegments.join('/');
  const target = `${apiUrl.replace(/\/$/, '')}/${path}${req.nextUrl.search}`;

  const headers = new Headers();
  const auth = req.headers.get('authorization');
  if (auth) {
    headers.set('authorization', auth);
  }

  const contentType = req.headers.get('content-type');
  if (contentType) {
    headers.set('content-type', contentType);
  }

  const body = method === 'GET' ? undefined : await req.text();
  const response = await fetch(target, {
    method,
    headers,
    body,
    cache: 'no-store',
  });

  const data = await response.text();
  return new Response(data, {
    status: response.status,
    headers: {
      'content-type': response.headers.get('content-type') || 'application/json',
    },
  });
}
