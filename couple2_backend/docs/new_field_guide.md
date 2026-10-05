# Guia: Adicionando Novos Campos ao Banco de Dados

Este guia mostra o passo a passo completo para adicionar um novo campo no modelo `User` (ou qualquer outro modelo).

---

## Exemplo Prático: Campo `picture` (URL da foto do usuário)

### Passo 1: Atualizar o Schema do Prisma

Edite `prisma/schema.prisma` e adicione o novo campo no modelo:

```prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String?
  picture   String?  // ← Novo campo adicionado
  googleId  String?  @unique
  appleId   String?  @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  
  // ... resto do modelo
}
```

**Dica:** Use `?` para campos opcionais, remova para campos obrigatórios.

---

### Passo 2: Atualizar a Strategy (se for de login social)

Se o campo vem de um provider externo (Google/Apple), atualize a interface e o método de validação:

**`src/auth/strategies/google.strategy.ts`:**

```typescript
export interface GoogleUser {
  googleId: string;
  email: string;
  name: string | null;
  picture: string | null;  // ← Adicionar na interface
}

// No método validateIdToken:
return {
  googleId: payload.sub,
  email: payload.email,
  name: payload.name || null,
  picture: payload.picture || null,  // ← Extrair do payload
};
```

---

### Passo 3: Atualizar o Service para Salvar o Campo

**`src/auth/auth.service.ts`:**

No método `findOrCreateGoogleUser` (ou equivalente):

```typescript
// Ao criar novo usuário
return this.prisma.user.create({
  data: {
    email: googleUser.email,
    name: googleUser.name,
    picture: googleUser.picture,  // ← Adicionar aqui
    googleId: googleUser.googleId,
  },
});
```

**Opcional:** Se quiser atualizar o campo em logins subsequentes:

```typescript
if (user) {
  // Atualizar dados do usuário existente
  return this.prisma.user.update({
    where: { id: user.id },
    data: { 
      googleId: googleUser.googleId,
      picture: googleUser.picture,  // ← Atualizar foto
    },
  });
}
```

---

### Passo 4: Atualizar as Respostas da API

**`src/auth/auth.controller.ts`:**

No endpoint `/auth/me` (ou onde você retorna dados do usuário):

```typescript
return {
  user: {
    id: user.id,
    email: user.email,
    name: user.name,
    picture: user.picture,  // ← Incluir no response
    createdAt: user.createdAt,
  },
  // ...
};
```

**Para dados do parceiro também:**

```typescript
partner: isPaired
  ? {
      id: user.partner!.id,
      name: user.partner!.name,
      email: user.partner!.email,
      picture: user.partner!.picture,  // ← Incluir aqui também
    }
  : null,
```

---

### Passo 5: Criar e Aplicar a Migration

Execute o comando:

```bash
npx prisma migrate dev --name add_user_picture
```

**O que esse comando faz:**
1. Gera um arquivo SQL em `prisma/migrations/XXXXXX_add_user_picture/`
2. Aplica a migration no banco de dados (adiciona a coluna)
3. Regenera o Prisma Client com o novo campo
4. Atualiza os tipos TypeScript automaticamente

**Exemplo de SQL gerado:**

```sql
-- AlterTable
ALTER TABLE "users" ADD COLUMN "picture" TEXT;
```

---

### Passo 6: Testar

**No Insomnia/Postman:**

```bash
POST http://localhost:3000/auth/google
Content-Type: application/json

{
  "idToken": "seu_token_aqui"
}
```

**Resposta esperada:**

```json
{
  "accessToken": "...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "Nome do Usuário",
    "picture": "https://lh3.googleusercontent.com/...",
    "partnerId": null,
    "pairingCode": "ABC123",
    "pairingCodeExpiresAt": "2024-02-18T12:00:00.000Z"
  }
}
```

---

## Checklist Completo

- [ ] Adicionar campo no `prisma/schema.prisma`
- [ ] Atualizar interface TypeScript (se aplicável)
- [ ] Atualizar lógica de extração de dados (strategy)
- [ ] Atualizar criação/atualização no banco (service)
- [ ] Incluir campo nas respostas da API (controller)
- [ ] Rodar `npx prisma migrate dev --name nome_descritivo`
- [ ] Testar endpoint e verificar resposta
- [ ] (Opcional) Atualizar documentação da API

---

## Tipos de Campos Comuns no Prisma

```prisma
// String
bio String?

// Número inteiro
age Int?

// Booleano
isVerified Boolean @default(false)

// Data/hora
lastLoginAt DateTime?

// Enum
role Role @default(USER)

// JSON (para dados flexíveis)
preferences Json?

// Array (PostgreSQL)
tags String[]
```

---

## Comandos Úteis

```bash
# Ver diferenças antes de criar migration
npx prisma migrate dev --create-only --name test_changes

# Resetar banco (APAGA TUDO!)
npx prisma migrate reset

# Ver banco visualmente
npx prisma studio

# Regenerar Prisma Client sem migration
npx prisma generate

# Ver status das migrations
npx prisma migrate status
```

---

## Troubleshooting

### "Type errors after migration"

Execute no VS Code: `Cmd+Shift+P` → "TypeScript: Restart TS Server"

### "Migration failed"

- Verifique se o banco está rodando: `docker ps`
- Verifique DATABASE_URL no `.env`
- Se necessário, reverta: `npx prisma migrate resolve --rolled-back MIGRATION_NAME`

### "Field not appearing in responses"

Certifique-se de:
1. Incluir o campo nas queries Prisma
2. Adicionar na resposta do controller
3. Reiniciar o servidor (`npm run dev`)

---

## Exemplo: Campo Customizado com Validação

**Schema:**

```prisma
model User {
  phoneNumber String? @unique
}
```

**DTO de validação (class-validator):**

```typescript
import { IsPhoneNumber, IsOptional } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsPhoneNumber('BR')
  phoneNumber?: string;
}
```

---

## Boas Práticas

✅ **Use nomes descritivos nas migrations:** `add_user_picture` não `update`

✅ **Campos sensíveis como opcional primeiro:** Adicione como `String?`, depois mude para obrigatório em outra migration

✅ **Sempre teste localmente antes de production**

✅ **Commit das migrations no Git:** Os arquivos em `prisma/migrations/` devem ir para o repositório

✅ **Documente mudanças importantes:** Atualize READMEs ou guias de API

❌ **Não edite migrations aplicadas:** Crie uma nova migration para mudanças

❌ **Não rode migrate reset em produção:** Vai deletar todos os dados!

---

## Exemplo Completo: Adicionando Campo `phoneNumber`

### 1. Schema
```prisma
model User {
  phoneNumber String? @unique
}
```

### 2. DTO (opcional)
```typescript
export class UpdateProfileDto {
  phoneNumber?: string;
}
```

### 3. Service
```typescript
async updateProfile(userId: string, dto: UpdateProfileDto) {
  return this.prisma.user.update({
    where: { id: userId },
    data: { phoneNumber: dto.phoneNumber },
  });
}
```

### 4. Controller
```typescript
@Patch('profile')
@UseGuards(JwtAuthGuard)
async updateProfile(@GetUser() user: User, @Body() dto: UpdateProfileDto) {
  return this.authService.updateProfile(user.id, dto);
}
```

### 5. Migration
```bash
npx prisma migrate dev --name add_user_phone_number
```

---

**Pronto!** Agora você sabe como adicionar qualquer campo novo ao sistema. 🚀
