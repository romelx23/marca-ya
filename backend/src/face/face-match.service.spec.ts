import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { EMBEDDING_DIM, encryptEmbedding, normalize } from './face.crypto.js';
import { FaceMatchService } from './face-match.service.js';
import type { FaceStore } from './face.store.js';

const KEY = randomBytes(32).toString('base64');
const env = { FACE_ENCRYPTION_KEY: KEY };

/** Vector aleatorio de la dimensión del modelo: dos vectores al azar son casi ortogonales. */
const randomVec = () => Array.from({ length: EMBEDDING_DIM }, () => Math.random() - 0.5);

function storeWith(encrypted: Record<string, string[]>): FaceStore {
  return {
    listTemplates: async (id: string) => encrypted[id] ?? [],
  } as unknown as FaceStore;
}

describe('FaceMatchService', () => {
  it('acepta un rostro igual a una plantilla guardada', async () => {
    const enrolled = randomVec();
    const service = new FaceMatchService(
      storeWith({ ana: [encryptEmbedding(normalize(enrolled), Buffer.from(KEY, 'base64'))] }),
    );
    const r = await service.verify('ana', enrolled, env);
    expect(r.matched).toBe(true);
    expect(r.score).toBeCloseTo(1, 4);
  });

  it('rechaza el rostro de otra persona', async () => {
    const service = new FaceMatchService(
      storeWith({ ana: [encryptEmbedding(normalize(randomVec()), Buffer.from(KEY, 'base64'))] }),
    );
    const r = await service.verify('ana', randomVec(), env);
    expect(r.matched).toBe(false);
    expect(r.score).not.toBeNull();
  });

  it('sin plantillas devuelve score null (no es un rechazo, es falta de registro)', async () => {
    const service = new FaceMatchService(storeWith({}));
    expect(await service.verify('nadie', randomVec(), env)).toEqual({ matched: false, score: null });
  });

  it('usa la mejor plantilla de varias capturas', async () => {
    const key = Buffer.from(KEY, 'base64');
    const target = randomVec();
    const service = new FaceMatchService(
      storeWith({
        ana: [
          encryptEmbedding(normalize(randomVec()), key),
          encryptEmbedding(normalize(randomVec()), key),
          encryptEmbedding(normalize(target), key),
        ],
      }),
    );
    expect((await service.verify('ana', target, env)).matched).toBe(true);
  });

  it('el umbral se puede configurar con FACE_MATCH_THRESHOLD', () => {
    const service = new FaceMatchService(storeWith({}));
    expect(service.threshold({})).toBe(0.5);
    expect(service.threshold({ FACE_MATCH_THRESHOLD: '0.8' })).toBe(0.8);
    expect(service.threshold({ FACE_MATCH_THRESHOLD: 'x' })).toBe(0.5);
  });

  it('rechaza embeddings con dimensión incorrecta', async () => {
    const service = new FaceMatchService(storeWith({ ana: [] }));
    await expect(service.verify('ana', [1, 2, 3], env)).rejects.toThrow();
  });
});
