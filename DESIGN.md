# DESIGN.md

<!-- This file captures your project's design system in a format AI agents can read natively.
     It is the single source of truth for how the project should look and feel.
     Fill in the sections relevant to your project, delete the rest.
     See: https://github.com/VoltAgent/awesome-design-md -->

## Visual Theme & Atmosphere

<!-- What emotional impression should the UI create? (e.g., "Professional and calm", "Bold and energetic") -->

## Color Palette & Roles

<!-- Define colors and their semantic roles -->

| Role | Value | Usage |
|---|---|---|
| Primary | | Buttons, links, active states |
| Secondary | | Supporting UI elements |
| Background | | Page and card backgrounds |
| Surface | | Elevated containers |
| Text | | Body text |
| Text Muted | | Secondary text, placeholders |
| Error | | Error states, destructive actions |
| Warning | | Warning states, caution |
| Success | | Success states, confirmations |
| Border | | Dividers, input borders |

<!-- Dark mode overrides, if applicable -->

## Typography Rules

| Element | Font | Size | Weight | Line Height |
|---|---|---|---|---|
| H1 | | | | |
| H2 | | | | |
| H3 | | | | |
| Body | | | | |
| Small | | | | |
| Code | | | | |

<!-- Max 2-3 font families. State them here. -->

## Component Stylings

<!-- Define the visual treatment for core UI elements -->

### Buttons

| Variant | Background | Text | Border | Radius | Padding |
|---|---|---|---|---|---|
| Primary | | | | | |
| Secondary | | | | | |
| Ghost | | | | | |
| Destructive | | | | | |

### Cards

<!-- Background, shadow, border, radius, padding -->

### Inputs

<!-- Border, radius, padding, focus ring, error state -->

### Modals / Dialogs

<!-- Overlay, width, padding, animation -->

## Layout Principles

<!-- Grid system, max content width, spacing scale, page structure -->

- Spacing scale:
- Max content width:
- Grid columns:
- Gutter:

## Depth & Elevation

<!-- Shadow scale for layering UI elements -->

| Level | Shadow | Usage |
|---|---|---|
| 0 | none | Flat elements |
| 1 | | Cards, dropdowns |
| 2 | | Modals, popovers |
| 3 | | Toasts, tooltips |

## Do's and Don'ts

### Do

-

### Don't

-

## Responsive Behavior

| Breakpoint | Width | Layout Changes |
|---|---|---|
| Mobile | | |
| Tablet | | |
| Desktop | | |
| Wide | | |

## Agent Prompt Guide

<!-- Instructions for AI agents generating UI for this project -->

When generating UI for this project:

1. Always use the color tokens defined above — never hardcode hex values
2. Follow the spacing scale — no arbitrary pixel values
3. Match the component stylings for buttons, cards, inputs
4. Check the Do's and Don'ts before creating new patterns
5. Test responsive behavior at all breakpoints listed above
