/** Puerto de persistencia de empleados. Los servicios dependen de esta interfaz, no de una base concreta. */

export type Role = 'employee' | 'manager' | 'hr' | 'admin';

export interface EmployeeRecord {
  id: string;
  email: string;
  passwordHash: string;
  /** PIN de respaldo para marcar sin rostro (hash). Null si el empleado aún no lo definió. */
  pinHash: string | null;
  fullName: string;
  documentId: string | null;
  role: Role;
  active: boolean;
  createdAt: Date;
}

export interface NewEmployee {
  email: string;
  passwordHash: string;
  fullName: string;
  documentId: string | null;
  role: Role;
}

export interface EmployeeStore {
  findById(id: string): Promise<EmployeeRecord | null>;
  /** El correo ya viene en minúsculas. */
  findByEmail(email: string): Promise<EmployeeRecord | null>;
  /** Ordenados por nombre. */
  findAll(): Promise<EmployeeRecord[]>;
  count(): Promise<number>;
  add(employee: NewEmployee): Promise<EmployeeRecord>;
  /** Guarda todos los campos de un empleado existente. */
  save(employee: EmployeeRecord): Promise<EmployeeRecord>;
}

export const EMPLOYEE_STORE = Symbol('EMPLOYEE_STORE');
