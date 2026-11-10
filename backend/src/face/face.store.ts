/** Puerto de persistencia del reconocimiento facial: consentimiento y plantillas (embeddings cifrados). */

export interface FaceConsentRecord {
  id: string;
  employeeId: string;
  version: string;
  acceptedAt: Date;
  revokedAt: Date | null;
}

export interface FaceStore {
  /** El consentimiento más reciente, esté o no revocado. */
  latestConsent(employeeId: string): Promise<FaceConsentRecord | null>;
  addConsent(employeeId: string, version: string): Promise<FaceConsentRecord>;
  /** Marca como revocado el consentimiento vigente, si hay uno. */
  revokeConsent(employeeId: string): Promise<void>;
  templateCount(employeeId: string): Promise<number>;
  /** Textos cifrados de las plantillas del empleado. */
  listTemplates(employeeId: string): Promise<string[]>;
  /** Reemplaza todas las plantillas del empleado de forma atómica. Cada texto ya viene cifrado. */
  replaceTemplates(employeeId: string, encryptedEmbeddings: string[]): Promise<void>;
  deleteTemplates(employeeId: string): Promise<void>;
}

export const FACE_STORE = Symbol('FACE_STORE');
