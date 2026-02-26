import jwt from 'jsonwebtoken';
import { config } from './env';

export interface JwtPayload {
  userId: string;
  role: string;
  type: 'access' | 'refresh';
  tokenFamily?: 'social' | 'admin';
}

export function generateAccessToken(userId: string, role: string): string {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return jwt.sign(
    { userId, role, type: 'access', tokenFamily: 'social' } as JwtPayload,
    config.jwt.secret,
    { expiresIn: config.jwt.accessExpiry } as any
  );
}

export function generateRefreshToken(userId: string, role: string): string {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return jwt.sign(
    { userId, role, type: 'refresh', tokenFamily: 'social' } as JwtPayload,
    config.jwt.secret,
    { expiresIn: config.jwt.refreshExpiry } as any
  );
}

export function verifyToken(token: string): JwtPayload {
  return jwt.verify(token, config.jwt.secret) as JwtPayload;
}

export function generateTokenPair(userId: string, role: string) {
  return {
    accessToken: generateAccessToken(userId, role),
    refreshToken: generateRefreshToken(userId, role),
  };
}

export function generateAdminAccessToken(userId: string, role: string): string {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return jwt.sign(
    { userId, role, type: 'access', tokenFamily: 'admin' } as JwtPayload,
    config.jwt.secret,
    { expiresIn: config.jwt.accessExpiry } as any
  );
}

export function generateAdminRefreshToken(userId: string, role: string): string {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return jwt.sign(
    { userId, role, type: 'refresh', tokenFamily: 'admin' } as JwtPayload,
    config.jwt.secret,
    { expiresIn: config.jwt.refreshExpiry } as any
  );
}

export function generateAdminTokenPair(userId: string, role: string) {
  return {
    accessToken: generateAdminAccessToken(userId, role),
    refreshToken: generateAdminRefreshToken(userId, role),
  };
}
