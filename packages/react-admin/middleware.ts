import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('accessToken')?.value
  const isLoginPage = request.nextUrl.pathname === '/login'

  // If already authenticated and trying to visit login, send to dashboard
  if (token && isLoginPage) {
    return NextResponse.redirect(new URL('/', request.url))
  }

  // All other routing (including unauthenticated → /login) is handled
  // client-side in (dashboard)/layout.tsx — this avoids the blank-screen
  // race between middleware redirect and client layout hydration
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api).*)'],
}
