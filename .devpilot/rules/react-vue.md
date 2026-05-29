# React / Vue / Next.js Rules
> APPLIES ONLY IF `project.config.md → stack.frontend` is `react`, `vue`, or `nextjs`.

### React / Next.js
- Function components + hooks only. Rules of hooks strictly observed.
- Type props explicitly; no `any`. Prefer discriminated unions over loose objects.
- Derive state — don't duplicate it. `useMemo`/`useCallback` only where it measurably helps.
- Data fetching via the project's existing layer (React Query/SWR/server components) — don't add another.
- No business logic in JSX; extract to hooks/helpers. Keys on lists must be stable (not the index).

### Vue
- `<script setup>` + Composition API for new components. Typed `defineProps`/`defineEmits`.
- Reactive state via `ref`/`reactive`/`computed`; avoid mutating props.

### Shared
- Styling per the project's system (CSS modules / Tailwind / tokens). No hardcoded colors if tokens exist.
- Accessibility: semantic elements, labels on inputs, keyboard reachable.
- Tests with the project runner (Vitest/Jest/Testing Library): render + one interaction per new component.
- Verify before commit: lint + build (`npm run build`) && tests.
