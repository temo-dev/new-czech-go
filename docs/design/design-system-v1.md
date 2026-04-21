# Design System V1

## Purpose
This document is the shared UI source of truth for the first visual system of `A2 Mluveni Sprint`.

It exists to keep `Flutter` and `Next.js CMS` aligned while the product is still moving quickly.

The design direction borrows from the strengths of `Babbel`:
- calm, bright surfaces
- disciplined use of orange
- card-based learning flows
- generous whitespace
- progress cues that feel supportive, not noisy

## Brand Mood
- Friendly, but not childish
- Calm and focused
- Motivational like a speaking coach
- Clean and minimal rather than playful or game-like

## Visual Principles
- One screen should focus on one main task.
- White and neutral surfaces should dominate the screen.
- Orange should mostly signal action, progress, or urgency.
- Blue should be used sparingly for guidance and secondary emphasis.
- Copy should feel supportive and clear, never exam-panic driven.
- UI density should stay low, especially on learner screens.

## Color Tokens

### Primary
- `primary`: `#F05A28`
- `primary-strong`: `#E4610A`
- `primary-soft`: `#FFF1EA`

### Accent
- `accent`: `#3D5BB5`
- `accent-soft`: `#EBF0FF`

### Neutral
- `background`: `#F7F8FA`
- `surface`: `#FFFFFF`
- `surface-muted`: `#F2F5F9`
- `border`: `#E4E8EF`

### Text
- `text-primary`: `#0D1218`
- `text-secondary`: `#495265`

### Status
- `success`: `#2F9E44`
- `success-soft`: `#EAF7EE`
- `danger`: `#C92A2A`

## Color Usage Ratio
- `70%` white and bright surfaces
- `20%` neutral support colors
- `10%` accent and CTA colors

The goal is controlled emphasis, not a saturated interface.

## Typography

### Heading Direction
Use a friendly but disciplined heading style that feels editorial rather than playful.

Preferred:
- `Playfair Display`

Fallbacks:
- `Feature Text`
- `Poppins`
- `Inter`
- system sans

For implementation in this repo, `Playfair Display` should be bundled as a local asset in both `CMS` and `Flutter` rather than fetched at runtime.

### Body Direction
Use a clean sans-serif with high readability.

Preferred:
- `Inter`

Fallbacks:
- `Roboto`
- system sans

### Sizing
- Hero title: `30-32px`
- Section title: `22-24px`
- Card title: `18-20px`
- Body: `14-16px`
- Micro labels: `12px`

### Weight
- Hero and key section titles: `700-800`
- Card titles and labels: `700`
- Body: `400-500`

## Spacing And Shape

### Spacing
- Major screen padding: `20-32px`
- Card padding: `18-24px`
- Tight stack gap: `6-8px`
- Standard stack gap: `12-16px`
- Section gap: `20-24px`

### Radius
- Pills and badges: `999px`
- Inputs and buttons: `14-16px`
- Cards: `20-28px`

## Components

### Cards
- Use cards as the default unit for modules, exercises, practice states, and CMS panels.
- Cards should rely on white or soft-neutral fills with subtle borders.
- Shadows should stay soft and roomy, never heavy.

### Buttons
- Primary button: orange fill, white text, strong contrast
- Secondary button: white or neutral surface with border
- Keep button height generous and touch-friendly

### Inputs
- Inputs should feel quiet and readable
- Use white or soft-neutral surfaces with subtle borders
- Focus state should move to orange or blue without becoming harsh

### Badges And Pills
- Use pills for task type, progress state, readiness level, or admin state
- Prefer soft fills with strong text color rather than saturated blocks

## Screen Principles

### Learner Screens
- Single-task flow
- Strong visual hierarchy
- Short copy blocks
- Feedback grouped into strengths, improvements, and retry guidance
- Progress should feel encouraging, not competitive

### CMS Screens
- Still calm and bright, but denser than learner screens
- Prioritize scanability for forms and content lists
- Use clear panel separation rather than decorative color blocks

## Motion
- Keep motion light and meaningful
- Prefer subtle loading, progress, and reveal patterns
- Avoid bouncy or game-like motion in the first version

## Do
- Use orange with restraint
- Leave space around primary tasks
- Break content into small chunks
- Keep labels explicit and calm
- Let typography carry hierarchy before color does

## Do Not
- Do not flood screens with orange
- Do not overload a single screen with multiple competing tasks
- Do not use dark, high-stress exam visuals
- Do not mix unrelated visual styles between Flutter and CMS
- Do not add gamification visuals that undercut the serious exam-coach tone

## Surface Notes

### Flutter
- Learner screens should be the cleanest expression of the system
- Practice and feedback states should feel reassuring and spacious

### CMS
- CMS can be slightly more structured and information-dense
- It should still feel like the same product family, not a different admin brand

## Implementation Status
The current codebase should align to this document first in:
- `flutter_app/lib/main.dart`
- `cms/app/globals.css`
- `cms/components/exercise-dashboard.tsx`

The current font assets are bundled locally in:
- `cms/public/fonts/playfair-display/`
- `flutter_app/assets/fonts/playfair_display/`

As more screens are added, this file should stay small and stable. If a design decision becomes cross-cutting, update this document before spreading the change across the app.
