import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { ServiceUnavailableException } from '@nestjs/common';

/** Dimensión de los embeddings que acepta el servidor. Debe coincidir con el modelo del teléfono. */
export const EMBEDDING_DIM = Number(process.env.FACE_EMBEDDING_DIM ?? 128);

/**
 * Clave AES-256 desde FACE_ENCRYPTION_KEY (32 bytes en base64).
 * Generar con: node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
 */
export function faceKey(env = process.env): Buffer {
  const raw = env.FACE_ENCRYPTION_KEY;
  if (!raw) throw new ServiceUnavailableException('Reconocimiento facial no configurado: falta FACE_ENCRYPTION_KEY');
  const key = Buffer.from(raw, 'base64');
  if (key.length !== 32) throw new Error('FACE_ENCRYPTION_KEY debe ser de 32 bytes en base64');
  return key;
}

/** Escala el vector a norma 1, para que la similitud coseno sea un producto punto. */
export function normalize(vec: number[]): number[] {
  const norm = Math.sqrt(vec.reduce((s, v) => s + v * v, 0));
  return vec.map((v) => v / norm);
}

/** Similitud coseno de dos vectores normalizados (es un producto punto). */
export function cosine(a: number[], b: number[]): number {
  let dot = 0;
  for (let i = 0; i < a.length; i++) dot += a[i]! * b[i]!;
  return dot;
}

/** Cifra un embedding con AES-256-GCM. Formato: base64(iv[12] | tag[16] | texto cifrado). */
export function encryptEmbedding(vec: number[], key: Buffer): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const plain = Buffer.from(new Float32Array(vec).buffer);
  const body = Buffer.concat([cipher.update(plain), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), body]).toString('base64');
}

export function decryptEmbedding(encrypted: string, key: Buffer): number[] {
  const buf = Buffer.from(encrypted, 'base64');
  const decipher = createDecipheriv('aes-256-gcm', key, buf.subarray(0, 12));
  decipher.setAuthTag(buf.subarray(12, 28));
  const plain = Buffer.concat([decipher.update(buf.subarray(28)), decipher.final()]);
  return Array.from(new Float32Array(plain.buffer.slice(plain.byteOffset, plain.byteOffset + plain.length)));
}
