import { BadRequestException, Inject, Injectable, Logger } from '@nestjs/common';
import { EMBEDDING_DIM, cosine, decryptEmbedding, faceKey, normalize } from './face.crypto.js';
import { FACE_STORE, type FaceStore } from './face.store.js';

/** Umbral por defecto de similitud coseno. Debe calibrarse con el piloto (FACE_MATCH_THRESHOLD). */
export const DEFAULT_MATCH_THRESHOLD = 0.5;

export interface FaceMatch {
  matched: boolean;
  /** Mejor similitud contra las plantillas del empleado; null si no tiene rostro registrado. */
  score: number | null;
}

/** Compara el embedding de una marcación con las plantillas cifradas del empleado. */
@Injectable()
export class FaceMatchService {
  private readonly log = new Logger('FaceMatch');
  constructor(@Inject(FACE_STORE) private readonly faces: FaceStore) {}

  threshold(env = process.env): number {
    const t = Number(env.FACE_MATCH_THRESHOLD ?? DEFAULT_MATCH_THRESHOLD);
    return Number.isFinite(t) ? t : DEFAULT_MATCH_THRESHOLD;
  }

  async verify(employeeId: string, embedding: number[], env = process.env): Promise<FaceMatch> {
    validate(embedding);
    const encrypted = await this.faces.listTemplates(employeeId);
    if (encrypted.length === 0) return { matched: false, score: null };
    const key = faceKey(env);
    const query = normalize(embedding);
    const score = Math.max(...encrypted.map((e) => cosine(normalize(decryptEmbedding(e, key)), query)));
    // TEMPORAL (calibración): solo la similitud, sin imágenes ni embeddings.
    this.log.log(`similitud ${score.toFixed(3)} umbral ${this.threshold(env)}`);
    return { matched: score >= this.threshold(env), score };
  }
}

function validate(v: number[]) {
  if (!Array.isArray(v) || v.length !== EMBEDDING_DIM || v.some((x) => typeof x !== 'number' || !Number.isFinite(x))) {
    throw new BadRequestException(`El embedding debe tener ${EMBEDDING_DIM} números finitos`);
  }
  if (v.every((x) => x === 0)) throw new BadRequestException('Embedding vacío');
}
