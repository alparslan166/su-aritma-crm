# Backend Development Guide

Bu dokümantasyon, backend geliştirme için proje yapısı ve kodlama standartlarını açıklar.

## Proje Yapısı

```
src/
├── app.ts                 # Express app factory
├── index.ts               # Application entry point
├── config/
│   └── env.ts             # Environment configuration
├── lib/
│   ├── prisma.ts          # Prisma Client instance
│   ├── logger.ts          # Logger utility
│   ├── generators.ts      # ID generators
│   └── tenant.ts          # Tenant context (admin/personnel ID extraction)
├── middleware/
│   └── error-handler.ts   # Error handling middleware & AppError class
├── modules/               # Feature modules (domain-based)
│   └── {module-name}/
│       ├── {module}.controller.ts  # Request handlers
│       ├── {module}.service.ts     # Business logic (optional)
│       └── {module}.router.ts       # Route definitions
├── routes/
│   └── index.ts           # Main router (combines all module routers)
└── queues/                # Background job queues
```

## Kodlama Standartları

### 1. Module Yapısı

Her feature için `src/modules/{module-name}/` klasörü altında:

- **Controller** (`{module}.controller.ts`): Request/Response handling
- **Service** (`{module}.service.ts`): Business logic (opsiyonel, karmaşık logic için)
- **Router** (`{module}.router.ts`): Route tanımları

### 2. Controller Pattern

```typescript
import { NextFunction, Request, Response } from "express";
import { z } from "zod";
import { prisma } from "@/lib/prisma";
import { getAdminId, getPersonnelId } from "@/lib/tenant";
import { AppError } from "@/middleware/error-handler";

// Request validation schema
const createSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
});

// Named export handler function
export const createHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const payload = createSchema.parse(req.body);
    
    // Business logic veya service call
    const result = await prisma.model.create({
      data: { ...payload, adminId },
    });
    
    res.json({ success: true, data: result });
  } catch (error) {
    next(error as Error);
  }
};
```

### 3. Service Pattern (Opsiyonel)

Karmaşık business logic için service kullanın:

```typescript
import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";

class MyService {
  async create(adminId: string, payload: CreatePayload) {
    // Complex business logic here
    return await prisma.model.create({
      data: { ...payload, adminId },
    });
  }
}

export const myService = new MyService();
```

### 4. Router Pattern

```typescript
import { Router } from "express";
import {
  createHandler,
  listHandler,
  getHandler,
  updateHandler,
  deleteHandler,
} from "./module.controller";

const router = Router();

router.get("/", listHandler);
router.get("/:id", getHandler);
router.post("/", createHandler);
router.put("/:id", updateHandler);
router.delete("/:id", deleteHandler);

export const moduleRouter = router;
```

### 5. Routes Registration

`src/routes/index.ts` dosyasına yeni router'ı ekleyin:

```typescript
import { moduleRouter } from "@/modules/module/module.router";

router.use("/module", moduleRouter);
```

## Import Paths

Proje `@/` alias kullanır (tsconfig-paths ile):

- `@/lib/prisma` → `src/lib/prisma`
- `@/modules/...` → `src/modules/...`
- `@/middleware/...` → `src/middleware/...`
- `@/config/...` → `src/config/...`

## Prisma Kullanımı

### Prisma Client Import

```typescript
import { prisma } from "@/lib/prisma";
```

### Query Örnekleri

```typescript
// Find unique
const admin = await prisma.admin.findUnique({
  where: { id: adminId },
});

// Find many with filters
const customers = await prisma.customer.findMany({
  where: {
    adminId,
    status: "ACTIVE",
    name: { contains: search, mode: "insensitive" },
  },
  orderBy: { createdAt: "desc" },
});

// Create
const customer = await prisma.customer.create({
  data: {
    adminId,
    name: "John Doe",
    phone: "5551234567",
    address: "123 Main St",
  },
});

// Update
const updated = await prisma.customer.update({
  where: { id: customerId },
  data: { name: "Jane Doe" },
});

// Delete
await prisma.customer.delete({
  where: { id: customerId },
});

// Transaction
await prisma.$transaction(async (tx) => {
  const customer = await tx.customer.create({ data: {...} });
  await tx.job.create({ data: { customerId: customer.id, ...} });
});
```

### Decimal Kullanımı

Prisma Decimal tipi için:

```typescript
import { Prisma } from "@prisma/client";

const amount = new Prisma.Decimal("123.45");
```

## Error Handling

### AppError Kullanımı

```typescript
import { AppError } from "@/middleware/error-handler";

// 404 Not Found
throw new AppError("Resource not found", 404);

// 400 Bad Request
throw new AppError("Invalid input", 400);

// 401 Unauthorized
throw new AppError("Unauthorized", 401);

// 403 Forbidden
throw new AppError("Access denied", 403);
```

### Controller'da Error Handling

```typescript
export const handler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Your code
  } catch (error) {
    next(error as Error); // Error handler middleware'e gönder
  }
};
```

## Tenant Context

Admin veya Personnel ID'yi request'ten almak için:

```typescript
import { getAdminId, getPersonnelId } from "@/lib/tenant";

// Admin ID (x-admin-id header'dan)
const adminId = getAdminId(req);

// Personnel ID (x-personnel-id header'dan)
const personnelId = getPersonnelId(req);
```

## Request Validation

Zod schema kullanarak:

```typescript
import { z } from "zod";

const createSchema = z.object({
  name: z.string().min(2),
  email: z.string().email().optional(),
  age: z.number().int().positive().optional(),
});

// Controller'da
const payload = createSchema.parse(req.body);
```

## Response Format

Tüm API response'ları standart format kullanır:

```typescript
// Success
res.json({
  success: true,
  data: result,
});

// Error (middleware tarafından otomatik)
{
  success: false,
  message: "Error message",
  // development'ta stack ve details eklenir
}
```

## Environment Variables

`.env` dosyasında:

```env
NODE_ENV=development
PORT=4000
DATABASE_URL=postgresql://...
DIRECT_URL=postgresql://...
PRISMA_FORCE_UNSECURE_TLS=1
AWS_REGION=eu-central-1
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_MEDIA_BUCKET=...
FCM_SERVER_KEY=...
REDIS_URL=...
MAINTENANCE_CRON=0 * * * *
```

## API Base URL

Development: `http://localhost:4000/api`

## Yeni Feature Ekleme Adımları

1. **Module klasörü oluştur**: `src/modules/{module-name}/`

2. **Controller oluştur**: `{module}.controller.ts`
   ```typescript
   export const listHandler = async (req, res, next) => { ... };
   export const createHandler = async (req, res, next) => { ... };
   ```

3. **Service oluştur** (opsiyonel): `{module}.service.ts`
   ```typescript
   class ModuleService { ... }
   export const moduleService = new ModuleService();
   ```

4. **Router oluştur**: `{module}.router.ts`
   ```typescript
   const router = Router();
   router.get("/", listHandler);
   export const moduleRouter = router;
   ```

5. **Routes'a ekle**: `src/routes/index.ts`
   ```typescript
   import { moduleRouter } from "@/modules/module/module.router";
   router.use("/module", moduleRouter);
   ```

## Testing

API endpoint'lerini test etmek için:

```bash
# Health check
curl http://localhost:4000/api/health

# With authentication header
curl -H "x-admin-id: ADMIN-ID" http://localhost:4000/api/customers
```

## Notlar

- **Named exports** kullanın, default export değil
- **TypeScript** strict mode aktif
- **Zod** validation için kullanılır
- **Prisma** ORM olarak kullanılır
- **Express** web framework
- **Error handling** middleware ile merkezi yönetilir
- **Tenant isolation** admin/personnel ID ile sağlanır

