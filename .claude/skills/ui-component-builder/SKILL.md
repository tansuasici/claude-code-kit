---
name: ui-component-builder
description: Build production-ready UI components with accessibility, loading/empty/error states, responsive behavior, and reusable props — not retrofitted polish. Use when creating a new component. To review an existing UI use /design-review instead.
user-invocable: true
---

# UI Component Builder

## Core Rule

Production-ready means accessibility, states (loading/empty/error), edge cases, and responsive behavior are designed first — not retrofitted after the happy path ships.

## Kit Context

Before starting:

1. Read `CODEBASE_MAP.md` to identify the project's UI stack and component conventions
2. Read `DESIGN.md` if it exists — it is the source of truth for tokens, colors, typography, spacing
3. Read `CLAUDE.project.md` if it exists — project-specific UI rules override kit defaults
4. Read any framework-specific docs in `agent_docs/project/` (e.g., Next.js conventions, design system docs)

If a component library is already in use (shadcn, MUI, Chakra, Radix, custom), build on top of it — do not introduce a parallel system.

## When to Use

Invoke with `/ui-component-builder <component-name>` when:

- A new reusable UI component is needed (button, modal, table, form field, card, etc.)
- An existing one-off piece of UI needs to be extracted into a reusable component
- A component needs to be redesigned to meet production standards (accessibility, states, responsive)
- You want a component-architecture review *before* writing the implementation

## When NOT to Use

- For pages, routes, or layouts — those are application composition, not component design
- For trivial wrappers (a 5-line styling div) — inline is fine
- For full app scaffolding — combine `/shape-spec` with stack-specific tooling
- For pure visual review of existing components — use `/design-review`
- For pure accessibility audit of existing components — use `/accessibility-audit`

## Hard Rules

- **No new design tokens without DESIGN.md.** If colors, spacing, or typography need extending, stop and ask. New tokens are a Protected Change.
- **Accessibility is not optional.** Every interactive component must be keyboard-navigable, have correct ARIA semantics, and pass WCAG 2.1 AA contrast.
- **States are required, not optional.** Loading, empty, error, and disabled states must be considered before the component is "done." Skipping them is shipping a demo, not a component.
- **Match existing style.** If the project uses controlled inputs, do not introduce uncontrolled ones. If it uses Tailwind, do not introduce CSS modules.
- **No props soup.** If a component grows past ~8 props, split it or use composition (slots/children). The skill must surface this trade-off explicitly.

## Process

### Phase 1: Context Gathering

Establish what the component must fit into:

1. **Identify the stack** — React/Vue/Svelte/Solid? TypeScript? Styling system (Tailwind, CSS-in-JS, modules)?
2. **Locate the component library** — shadcn, MUI, Radix, Chakra, custom? Where do components live (`components/ui/`, `app/_components/`, etc.)?
3. **Find similar existing components** — pattern-match: is there a `Button` you should mirror? An existing `Modal` whose API you should follow?
4. **Check design tokens** — extract from `DESIGN.md`, Tailwind config, theme files
5. **Note the consumers** — who will use this component? Forms? Lists? Modals?

Output of this phase: a short brief showing what you found. Do not skip — building components without locating prior art produces duplication.

### Phase 2: Component Architecture

Before writing code, design the shape:

**API surface**
- Name (clear, domain-appropriate, not generic like `Wrapper`)
- Props — required vs optional, controlled vs uncontrolled
- Slots / children patterns — for composition
- Imperative API (refs, methods) — only if absolutely needed
- Events / callbacks — naming convention from the project (`onChange` vs `onValueChange`)

**Composition strategy**
- Single component vs compound components (e.g., `<Select>`, `<Select.Item>`)
- Headless logic + styled wrapper (when reuse across themes matters)
- Single source of truth for state (controlled by default in form inputs)

**States to enumerate**

| State | Required? | Notes |
|---|---|---|
| Default | Always | The happy path |
| Hover / Focus | Interactive components | Visual + keyboard |
| Active / Pressed | Interactive components | Tactile feedback |
| Disabled | If component can be disabled | `aria-disabled` + style |
| Loading | If async work happens | Spinner / skeleton / shimmer |
| Empty | If component renders a collection | Helpful message + action |
| Error | If component can fail | Clear message + recovery path |
| Read-only | If editing can be locked | Visually distinct from disabled |

### Phase 3: Edge Cases & Responsive

Enumerate before implementation:

**Edge cases**
- Long content (overflow, truncation, wrap)
- No content (empty array, null, undefined)
- Many items (virtualization threshold? pagination?)
- Slow network (loading state visible?)
- Failed network (error state visible?)
- RTL languages (if i18n applies)
- Very long strings without spaces (`overflow-wrap: anywhere`)

**Responsive**
- Mobile (320-480px) — touch targets ≥44px, single column, no horizontal scroll
- Tablet (768-1024px) — adapt layout, not just shrink desktop
- Desktop (1280+) — readable line lengths (45-75 chars)
- Container queries when the component lives in variable-width slots

**Accessibility**
- Semantic HTML first (`<button>` not `<div onClick>`)
- Keyboard: Tab, Shift+Tab, Enter, Space, Esc — all must work
- ARIA: `role`, `aria-label`, `aria-describedby`, `aria-expanded`, etc. — only when semantic HTML doesn't cover it
- Focus management — visible focus ring, focus trap in modals, focus return on close
- Screen reader — labels, live regions for dynamic content, announcement of state changes
- Contrast — WCAG AA: 4.5:1 normal text, 3:1 large text and UI components

### Phase 4: Implementation

Now write the component. Order matters:

1. **Types / interfaces first** — define the contract before the body
2. **Semantic markup** — start with the right HTML element
3. **Accessibility wiring** — ARIA, keyboard handlers, focus management
4. **Styling** — using the project's system (Tailwind classes, CSS variables, etc.)
5. **States** — implement each enumerated state, not just the default
6. **Composition hooks** — `children`, slots, render props as appropriate
7. **Tests** — at minimum: renders, handles primary interaction, respects disabled state

Code example (React + TypeScript + Tailwind, adapt to your stack):

```tsx
type ButtonProps = {
  variant?: 'primary' | 'secondary' | 'ghost'
  size?: 'sm' | 'md' | 'lg'
  loading?: boolean
  disabled?: boolean
  leftIcon?: React.ReactNode
  rightIcon?: React.ReactNode
  children: React.ReactNode
} & Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'children'>

export function Button({
  variant = 'primary',
  size = 'md',
  loading = false,
  disabled = false,
  leftIcon,
  rightIcon,
  children,
  className,
  ...rest
}: ButtonProps) {
  const isDisabled = disabled || loading

  return (
    <button
      type="button"
      aria-busy={loading || undefined}
      aria-disabled={isDisabled || undefined}
      disabled={isDisabled}
      className={cn(buttonStyles({ variant, size }), className)}
      {...rest}
    >
      {loading ? <Spinner aria-hidden="true" /> : leftIcon}
      <span>{children}</span>
      {!loading && rightIcon}
    </button>
  )
}
```

### Phase 5: Documentation

Every reusable component ships with:

- **Props table** — name, type, default, description
- **Usage examples** — at least three: minimal, common, advanced
- **Accessibility notes** — keyboard shortcuts, ARIA roles in use, known limitations
- **Visual states** — list each state with when it appears

If the project has Storybook, MDX, or a docs site, add a story / page. Otherwise, put usage examples in a comment block at the top of the file.

## Output Format

When the skill runs, deliver the component as a structured package:

```markdown
# Component: <Name>

## Architecture Brief

- **Stack:** <framework + styling + types>
- **Library context:** <existing components mirrored / extended>
- **Composition pattern:** <single / compound / headless>
- **Why this shape:** <one paragraph rationale>

## Props API

| Prop | Type | Default | Required | Description |
|------|------|---------|----------|-------------|
| ... | ... | ... | ... | ... |

## States Enumerated

| State | Visual treatment | Interaction |
|---|---|---|
| Default | ... | ... |
| Loading | ... | ... |
| Empty | ... | ... |
| Error | ... | ... |
| Disabled | ... | ... |

## Edge Cases Handled

- Overflow: <strategy>
- No content: <empty state design>
- Failed load: <error recovery>
- Long strings: <wrap behavior>
- RTL: <handled / not applicable>

## Responsive Behavior

| Breakpoint | Adaptation |
|---|---|
| Mobile (320-480px) | ... |
| Tablet (768-1024px) | ... |
| Desktop (1280+) | ... |

## Accessibility

- **Semantic HTML:** <element + reason>
- **Keyboard:** Tab / Enter / Space / Esc — what each does
- **ARIA:** <attributes used and why>
- **Focus management:** <strategy>
- **Contrast:** <ratios met>

## Implementation

<code, in the project's conventions>

## Usage Examples

### Minimal
<code>

### Common case
<code>

### Advanced / composed
<code>

## Tests

<test file or test outline>

## Open Questions

<anything that requires user input — design tokens to add, ambiguous behavior, scope to confirm>
```

## Notes

- This skill **produces** components, unlike `/design-review` and `/accessibility-audit` which **review** them. Use those after this skill ships a component to catch what slipped through.
- If the user asks for "a quick button" — push back gently. Either it is a one-off (then inline it, no skill needed) or it is reusable (then states and accessibility are not optional).
- For component **libraries** (10+ components with shared system), invoke `/shape-spec` first to capture the system-level decisions, then run this skill per component.
- When a component is being **refactored**, also run `/refactoring-guide` to plan the migration of existing call sites.
- If the project lacks a `DESIGN.md`, surface this as an open question — building production components without tokens is a recipe for inconsistency.
