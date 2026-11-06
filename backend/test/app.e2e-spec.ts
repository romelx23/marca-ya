import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { App } from 'supertest/types';

const ADMIN = { email: 'admin@test.local', password: 'clave-de-prueba-1' };

describe('Auth + empleados (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    process.env.ADMIN_EMAIL = ADMIN.email;
    process.env.ADMIN_PASSWORD = ADMIN.password;
    const { AppModule } = await import('../src/app.module.js');
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }));
    await app.init();
  });

  afterAll(() => app.close());

  const login = (email: string, password: string) =>
    request(app.getHttpServer()).post('/auth/login').send({ email, password });

  it('rechaza credenciales inválidas', async () => {
    await login(ADMIN.email, 'otra-clave').expect(401);
    await login('nadie@test.local', ADMIN.password).expect(401);
  });

  it('exige token en /employees', async () => {
    await request(app.getHttpServer()).get('/employees').expect(401);
  });

  it('admin crea empleado, no expone el hash y el empleado no puede listar', async () => {
    const { body } = await login(ADMIN.email, ADMIN.password).expect(200);
    const adminAuth = `Bearer ${body.accessToken}`;
    expect(body.employee.passwordHash).toBeUndefined();

    const created = await request(app.getHttpServer())
      .post('/employees')
      .set('Authorization', adminAuth)
      .send({ email: 'Ana@Test.local', password: 'clave-ana-12345', fullName: 'Ana Ruiz' })
      .expect(201);
    expect(created.body.email).toBe('ana@test.local');
    expect(created.body.role).toBe('employee');
    expect(created.body.passwordHash).toBeUndefined();

    await request(app.getHttpServer())
      .post('/employees')
      .set('Authorization', adminAuth)
      .send({ email: 'ana@test.local', password: 'clave-ana-12345', fullName: 'Ana' })
      .expect(409);

    const ana = await login('ana@test.local', 'clave-ana-12345').expect(200);
    const anaAuth = `Bearer ${ana.body.accessToken}`;
    await request(app.getHttpServer()).get('/employees').set('Authorization', anaAuth).expect(403);
    const me = await request(app.getHttpServer()).get('/auth/me').set('Authorization', anaAuth).expect(200);
    expect(me.body.fullName).toBe('Ana Ruiz');

    await request(app.getHttpServer())
      .patch(`/employees/${created.body.id}`)
      .set('Authorization', adminAuth)
      .send({ active: false })
      .expect(200);
    await login('ana@test.local', 'clave-ana-12345').expect(401);
  });

  it('marcaciones: alterna entrada/salida, rechaza duplicadas y limita la vista de RRHH', async () => {
    const admin = await login(ADMIN.email, ADMIN.password).expect(200);
    const adminAuth = `Bearer ${admin.body.accessToken}`;
    await request(app.getHttpServer())
      .post('/employees')
      .set('Authorization', adminAuth)
      .send({ email: 'luis@test.local', password: 'clave-luis-12345', fullName: 'Luis Soto' })
      .expect(201);
    const luis = await login('luis@test.local', 'clave-luis-12345').expect(200);
    const luisAuth = `Bearer ${luis.body.accessToken}`;
    const http = () => request(app.getHttpServer());

    await http().post('/attendance').send({ type: 'in' }).expect(401);
    await http().post('/attendance').set('Authorization', luisAuth).send({ type: 'out' }).expect(409);

    const inRes = await http()
      .post('/attendance')
      .set('Authorization', luisAuth)
      .send({ type: 'in', latitude: -12.04, longitude: -77.03 })
      .expect(201);
    expect(inRes.body.type).toBe('in');
    expect(inRes.body.method).toBe('app');
    expect(inRes.body.latitude).toBe(-12.04);

    await http().post('/attendance').set('Authorization', luisAuth).send({ type: 'in' }).expect(409);
    await http().post('/attendance').set('Authorization', luisAuth).send({ type: 'out', latitude: 1 }).expect(400);

    const open = await http().get('/attendance/today').set('Authorization', luisAuth).expect(200);
    expect(open.body.checkedIn).toBe(true);
    expect(open.body.nextAction).toBe('out');
    expect(open.body.events).toHaveLength(1);

    await http().post('/attendance').set('Authorization', luisAuth).send({ type: 'out' }).expect(201);
    const closed = await http().get('/attendance/today').set('Authorization', luisAuth).expect(200);
    expect(closed.body.checkedIn).toBe(false);
    expect(closed.body.events).toHaveLength(2);

    const mine = await http().get('/attendance/me').set('Authorization', luisAuth).expect(200);
    expect(mine.body).toHaveLength(2);
    await http().get('/attendance/me?from=2026-13-45').set('Authorization', luisAuth).expect(400);

    await http().get('/attendance').set('Authorization', luisAuth).expect(403);
    const all = await http().get('/attendance').set('Authorization', adminAuth).expect(200);
    expect(all.body).toHaveLength(2);
    expect(all.body[0].employeeName).toBe('Luis Soto');
  });

  it('geocerca: rechaza marcar sin ubicación o lejos de la oficina', async () => {
    const admin = await login(ADMIN.email, ADMIN.password).expect(200);
    await request(app.getHttpServer())
      .post('/employees')
      .set('Authorization', `Bearer ${admin.body.accessToken}`)
      .send({ email: 'eva@test.local', password: 'clave-eva-123456', fullName: 'Eva Cruz' })
      .expect(201);
    const eva = await login('eva@test.local', 'clave-eva-123456').expect(200);
    const mark = (body: object) =>
      request(app.getHttpServer())
        .post('/attendance')
        .set('Authorization', `Bearer ${eva.body.accessToken}`)
        .send(body);

    process.env.OFFICE_LAT = '-12.04';
    process.env.OFFICE_LNG = '-77.03';
    process.env.OFFICE_RADIUS_M = '100';
    try {
      await mark({ type: 'in' }).expect(403);
      await mark({ type: 'in', latitude: -12.05, longitude: -77.03 }).expect(403);
      await mark({ type: 'in', latitude: -12.0401, longitude: -77.03 }).expect(201);
    } finally {
      delete process.env.OFFICE_LAT;
      delete process.env.OFFICE_LNG;
      delete process.env.OFFICE_RADIUS_M;
    }
  });

  it('dos marcaciones simultáneas del mismo empleado no se duplican', async () => {
    const admin = await login(ADMIN.email, ADMIN.password).expect(200);
    await request(app.getHttpServer())
      .post('/employees')
      .set('Authorization', `Bearer ${admin.body.accessToken}`)
      .send({ email: 'rosa@test.local', password: 'clave-rosa-12345', fullName: 'Rosa Paz' })
      .expect(201);
    const rosa = await login('rosa@test.local', 'clave-rosa-12345').expect(200);
    const send = () =>
      request(app.getHttpServer())
        .post('/attendance')
        .set('Authorization', `Bearer ${rosa.body.accessToken}`)
        .send({ type: 'in' });
    const results = await Promise.all([send(), send(), send()]);
    expect(results.map((r) => r.status).sort()).toEqual([201, 409, 409]);
  });
});
