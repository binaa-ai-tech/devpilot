# Accessibility — every UI ships usable by everyone (WCAG 2.1 AA)

Load this **before committing frontend UI** (Angular / React). Accessibility is not a polish pass;
it's part of done. Target **WCAG 2.1 AA**.

## The checklist (run before commit)
- [ ] **Semantic HTML first** — `<button>`, `<a>`, `<nav>`, `<main>`, headings in order. Reach for ARIA
      only when no native element fits; a wrong ARIA role is worse than none.
- [ ] **Keyboard** — every interactive element is reachable and operable by keyboard alone; visible
      focus ring; logical tab order; no keyboard traps. Custom widgets handle Enter/Space/Esc/arrows.
- [ ] **Labels** — every input has a programmatic label (`<label for>` / `aria-label`); icon-only
      buttons have an accessible name. Errors are announced, not just colored.
- [ ] **Contrast** — text ≥ 4.5:1 (large ≥ 3:1); never use color alone to convey meaning.
- [ ] **Images / media** — meaningful images have `alt`; decorative ones have empty `alt=""`.
- [ ] **Dynamic content** — async updates, toasts, and validation use live regions (`aria-live`)
      so screen readers announce them; modals trap focus and restore it on close.
- [ ] **Forms** — required/invalid state is programmatic (`aria-required`, `aria-invalid`), not visual only.
- [ ] **Motion / zoom** — respect `prefers-reduced-motion`; layout survives 200% zoom and reflow.

## Verify
Keyboard-only walkthrough of the feature + an automated pass (axe / Lighthouse). A control you
can't reach or name with the keyboard alone is a blocker, not a nit.
