import { NextRequest, NextResponse } from 'next/server'

async function proxyRequest(req: NextRequest, pathSegments: string[], method: string) {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'
  const path = pathSegments.join('/')
  const target = `${apiUrl}/${path}${req.nextUrl.search}`

  const headers = new Headers()
  const auth = req.headers.get('authorization')
  if (auth) headers.set('authorization', auth)
  const contentType = req.headers.get('content-type')
  if (contentType) headers.set('content-type', contentType)

  const body = method !== 'GET' && method !== 'HEAD' ? await req.text() : undefined

  try {
    const response = await fetch(target, { method, headers, body })
    const data = await response.text()

    return new NextResponse(data, {
      status: response.status,
      headers: {
        'content-type': response.headers.get('content-type') || 'application/json',
      },
    })
  } catch (err) {
    return NextResponse.json(
      { message: 'Failed to reach API server' },
      { status: 502 }
    )
  }
}

export async function GET(
  req: NextRequest,
  { params }: { params: { path: string[] } }
) {
  return proxyRequest(req, params.path, 'GET')
}

export async function POST(
  req: NextRequest,
  { params }: { params: { path: string[] } }
) {
  return proxyRequest(req, params.path, 'POST')
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: { path: string[] } }
) {
  return proxyRequest(req, params.path, 'PATCH')
}

export async function PUT(
  req: NextRequest,
  { params }: { params: { path: string[] } }
) {
  return proxyRequest(req, params.path, 'PUT')
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: { path: string[] } }
) {
  return proxyRequest(req, params.path, 'DELETE')
}
