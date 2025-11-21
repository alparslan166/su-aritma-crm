# Backend Servisi

Express + TypeScript tabanlı API servisidir.

## Kurulum

```
cd apps/backend
cp env.example .env
npm install
npm run prisma:generate
```

## Komutlar

| Komut | Açıklama |
| --- | --- |
| `npm run dev` | ts-node-dev + tsconfig-paths ile geliştirme sunucusu |
| `npm run build` | TypeScript derlemesi (`dist/`) |
| `npm run lint` | ESLint (strict) |
| `npm run typecheck` | Emit olmadan TS kontrolü |
| `npm test` | Jest + Supertest |
| `npm run prisma:migrate` | Prisma migrate dev |

