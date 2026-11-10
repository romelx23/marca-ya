import { existsSync } from 'node:fs';

/**
 * Carga backend/.env antes de que se evalúen los módulos (algunos leen process.env al cargarse).
 * Debe importarse la primera en main.ts. No sobrescribe variables que ya existan en el entorno.
 */
if (existsSync('.env')) process.loadEnvFile('.env');
