import { Logger } from '@nestjs/common';
import { existsSync, readFileSync } from 'node:fs';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

export const PUSH_TRANSPORT = Symbol('PUSH_TRANSPORT');

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface PushResult {
  sent: number;
  failed: number;
  /** Tokens que FCM rechazó por inválidos o desinstalados: hay que borrarlos. */
  invalidTokens: string[];
}

export interface PushTransport {
  /** false si faltan las credenciales de Firebase. */
  readonly enabled: boolean;
  send(tokens: string[], message: PushMessage): Promise<PushResult>;
}

const INVALID_CODES = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

/** Lee la cuenta de servicio de FIREBASE_SERVICE_ACCOUNT_JSON o del archivo FIREBASE_KEY_PATH (por defecto .firebase-key.json). */
export function loadServiceAccount(env = process.env): Record<string, unknown> | null {
  if (env.FIREBASE_SERVICE_ACCOUNT_JSON) return JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  const path = env.FIREBASE_KEY_PATH ?? '.firebase-key.json';
  return existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : null;
}

export class FirebaseTransport implements PushTransport {
  private readonly log = new Logger('FirebaseTransport');
  readonly enabled: boolean;

  constructor() {
    let account: Record<string, unknown> | null = null;
    try {
      account = loadServiceAccount();
    } catch (e) {
      this.log.error(`No se pudo leer la cuenta de servicio de Firebase: ${(e as Error).message}`);
    }
    this.enabled = account !== null;
    if (account && getApps().length === 0) {
      initializeApp({ credential: cert(account as Parameters<typeof cert>[0]) });
    }
    if (!this.enabled) {
      this.log.warn('Notificaciones push desactivadas: define FIREBASE_KEY_PATH o FIREBASE_SERVICE_ACCOUNT_JSON');
    }
  }

  async send(tokens: string[], message: PushMessage): Promise<PushResult> {
    const res = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
      android: { priority: 'high' },
    });
    const invalidTokens = res.responses
      .map((r, i) => (!r.success && r.error && INVALID_CODES.has(r.error.code) ? tokens[i]! : null))
      .filter((t): t is string => t !== null);
    return { sent: res.successCount, failed: res.failureCount, invalidTokens };
  }
}
