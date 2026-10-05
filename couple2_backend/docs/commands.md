SSH CONFIG:
`code ~/.ssh/config `

`git remote set-url origin git@github-vini:vinicius-gregorio/couple2_backend.git`



Local Supabase Postgres (repo root):
supabase start

API against that database:
cd couple2_backend && cp .env.example .env && npx prisma migrate deploy && npm run dev

API container (after supabase start):
cd couple2_backend && docker compose up --build
