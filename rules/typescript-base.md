# TypeScript base rules (workspace-shared)

These rules apply to **every TypeScript / JavaScript repo** in this workspace.

Repo-specific TS rules go in that repo's own `.claude/rules/typescript.md`. This file is the workspace baseline.

## Tooling baseline

- **TypeScript only** for new code. Don't add `.js` to a TS-configured project.
- **`pnpm`** is the canonical package manager. New repos default to `pnpm` unless the framework forces otherwise.
- **`npm`** is tolerated in repos that already use it. Don't switch them without a coordinated migration.
- **One package manager per repo.** No mixing `pnpm-lock.yaml` and `package-lock.json` in the same tree.

## Strictness

- `tsconfig.json` includes `"strict": true`. Don't downgrade.
- `"noImplicitAny": true`, `"strictNullChecks": true`, `"noUncheckedIndexedAccess": true` (for new repos).
- No `as any`. No `!` non-null assertion in new code unless every neighbor uses it and you've verified the invariant by hand.

## Module style

- ES modules everywhere. No CommonJS in new code.
- Path aliases (`@/...`) configured in `tsconfig.paths` and used consistently. Don't mix `@/components` with `../../components` in the same project.

## React (where applicable)

- Function components only. No class components in new code.
- Hooks rules: never call from a condition, never from a loop, never from a non-component function.
- State management:
  - Local state → `useState` / `useReducer`.
  - Cross-component, same-page → context with care, or zustand.
  - Server state → React Query / SWR. Don't reinvent caching.

## Linting / formatting

- **ESLint** + **Prettier** baseline. One eslint config per repo, no mixing.
- `// eslint-disable-next-line <rule>` requires a `Why:` comment, same rule as Python.

## Tests

- **Vitest** preferred for unit tests in new code. Jest tolerated in existing repos.
- **Playwright** for end-to-end. No Cypress in new code.
- `__tests__` colocation OR mirrored `tests/` directory — pick one per repo and stick with it.

## Server / API

- Next.js app router for new web frontends, page router only when matching an existing repo.
- API contracts validated at the boundary. `zod` for runtime validation of request/response.

## Logging

- Server logs go through a structured logger (`pino` is the workspace default). No `console.log` in production code.
- Browser: `console.log` allowed in dev paths, must be guarded (`if (process.env.NODE_ENV !== "production")`) in shipped code.
- **Never log secrets.** Same rule as Python base.

## What this rule explicitly does NOT cover

- UI / styling (TailwindCSS configs, CSS module conventions, design tokens). Per-repo, often tied to the design system.
- Framework choices beyond Next.js (Astro, Remix, etc.). Per-repo.
- Database / ORM conventions (Prisma, Drizzle). Per-repo.
- Build / deploy targets (Cloudflare Workers, Vercel, self-hosted). Per-repo.

The bar this file sets is "TypeScript that wouldn't surprise any contributor to any of our TS repos". Anything narrower lives in the repo that needs it.
