# SURAKSHAPATH_DESIGN_SYSTEM.md

**Version:** 1.0  
**Product:** SurakshaPath  
**Platform:** Flutter mobile application  
**Status:** Design source of truth for the MVP

---

## 1. Purpose

This document defines the single visual and interaction system for SurakshaPath. All screens and contributors must follow it. It synthesizes selected principles from the supplied Apple, Tesla, and PlayStation website design references while preserving SurakshaPath's own identity and emergency-use requirements.

SurakshaPath helps people understand their situation during a disaster, locate shelters, review hazard information, and access evacuation assistance. The interface must be calm, legible, fast to understand, and honest about what the app knows.

**Design concept:** Premium Minimalist Command Interface.

- Apple contributes clarity, whitespace, typography, and restrained surfaces.
- Tesla contributes visual restraint, strong composition, and confident hierarchy.
- PlayStation contributes purposeful light/dark chapter changes, immersive imagery, and clear content groupings.
- SurakshaPath contributes safety-first information design, emergency actions, and transparent data status.

These are design references only. Do not copy their logos, wordmarks, proprietary assets, exact layouts, or brand colors.

## 2. Non-negotiable product principles

1. **Truth before polish.** Never invent official endorsements, government affiliations, certifications, verification badges, live data, or capabilities.
2. **Emergency clarity before decoration.** A person must be able to find SOS, map, evacuation, and shelter actions quickly.
3. **No false reassurance.** Never label a route "safe", "verified safe", or "guaranteed" unless a trusted, current source and a defined validation process support that exact claim. Prefer "Suggested route" and show known hazards and data freshness.
4. **Label demo data.** Sample, seeded, mocked, or simulated information must be visibly labelled "Demo data" or "Sample data" near the information it describes.
5. **Explain uncertainty.** If GPS, connectivity, shelter capacity, hazard data, or route information is unavailable or stale, show that clearly.
6. **Preserve working functionality.** A visual redesign must not remove or silently change existing features, navigation, data models, services, or team-owned modules.
7. **Accessible in stressful conditions.** Use readable type, strong contrast, plain language, generous touch targets, and more than color alone to communicate status.

### Prohibited unsupported claims

Do not display any of the following unless the project team supplies verifiable evidence and an approved source:

- "NDMA verified", "NDMA approved", "Government approved", or similar.
- "Official emergency network" or official agency partnership claims.
- Live shelter availability or live occupancy when the app only uses local sample data.
- Real-time disaster alerts when alerts are static or simulated.
- Guaranteed safe routes or guaranteed rescue.
- Automatic SOS dispatch, automatic authority notification, or location sharing unless implemented, permissioned, tested, and actually connected to the described service.

When data is unavailable, say "Data unavailable" rather than filling the space with invented content.

## 3. Visual direction

### 3.1 Overall character

The interface should feel like a premium, modern navigation and emergency-assistance product:

- Minimal, editorial layouts with deliberate whitespace.
- Strong, concise headlines and calm supporting copy.
- Mostly flat surfaces; avoid stacks of floating cards.
- Full-width visual sections only where imagery or a map genuinely adds meaning.
- A small number of clear actions per screen.
- Consistent components across all five tabs.
- Selective dark sections for high-focus or immersive content, not a permanently dark interface.

### 3.2 Reference balance

Use this as a design balance, not a literal percentage requirement:

- **Apple-like clarity:** primary influence for spacing, readability, typography, and simple controls.
- **Tesla-like restraint:** influence for composition, minimal decoration, and confident use of whitespace.
- **PlayStation-like chapters:** influence for selective dark/light section transitions and imagery-led feature areas.
- **SurakshaPath safety layer:** overrides all references whenever contrast, accessibility, urgency, or comprehension requires it.

Do not reproduce the references' product marketing patterns when they conflict with an emergency task. A disaster app is a utility, not a showroom or entertainment catalogue.

## 4. Brand colors and semantic colors

The SurakshaPath brand palette is fixed. Reference-brand colors must not replace it.

### 4.1 Core brand tokens

| Token | Hex | Use |
|---|---|---|
| `brand.white` | `#FFFFFF` | Main canvas and light surfaces |
| `brand.blue.deep` | `#1E3A8A` | Primary brand surface, strong emphasis |
| `brand.blue` | `#3B82F6` | Primary interactive blue and map/navigation accents |
| `brand.green` | `#10B981` | Positive confirmation and verified availability states only |
| `text.primary` | `#0F172A` | Main text on light surfaces |

### 4.2 Supporting neutrals

| Token | Hex | Use |
|---|---|---|
| `surface.light` | `#FFFFFF` | Main light canvas |
| `surface.soft` | `#F8FAFC` | Quiet section and card surfaces |
| `surface.parchment` | `#F5F5F7` | Optional subtle section alternation |
| `surface.dark` | `#171A20` | Dark editorial sections |
| `surface.dark.card` | `#20242C` | Cards within dark sections |
| `text.secondary` | `#64748B` | Supporting text and metadata |
| `text.onDark` | `#FFFFFF` | Main text on dark surfaces |
| `text.onDark.secondary` | `#CBD5E1` | Supporting text on dark surfaces |
| `border.subtle` | `#E2E8F0` | Dividers and restrained outlines |

### 4.3 Safety and status colors

| Token | Hex | Meaning |
|---|---|---|
| `status.critical` | `#DC2626` | Critical danger / SOS |
| `status.high` | `#F97316` | High-risk warning |
| `status.moderate` | `#F59E0B` | Caution / moderate risk |
| `status.positive` | `#10B981` | Positive or available state when supported by data |
| `status.info` | `#3B82F6` | Informational state |
| `status.unknown` | `#64748B` | Unknown, unavailable, or unverified state |

**Semantic-color rules:**

- Do not use green merely to make a screen look reassuring. Use it only for a genuinely positive state supported by the displayed data.
- Pair every status color with a text label and, where useful, an icon or shape.
- Do not use red/orange/yellow as decoration. Reserve them for meaningful risk and warning information.
- SOS must remain visually distinct from ordinary primary actions.
- Do not use PlayStation orange, Tesla electric blue, Apple action blue, or their proprietary color tokens as SurakshaPath brand colors.

### 4.4 Gradient policy

The official brand gradient is `#1E3A8A` to `#3B82F6`. Use it sparingly for a single brand hero or primary emphasis area. Do not put gradients on every card, every button, map overlays, or text. Most surfaces should be flat white, soft neutral, or dark charcoal.

## 5. Typography

### 5.1 Font family

Use a clean system sans-serif. Prefer the platform system font where practical. Inter is an acceptable bundled alternative if consistent cross-platform rendering is required. Do not attempt to use proprietary SF Pro, Universal Sans, or PlayStation SST files unless the project has valid licensed assets.

### 5.2 Type scale

| Token | Size | Weight | Line height | Use |
|---|---:|---:|---:|---|
| `display.large` | 36 px | 600 | 1.12 | Rare home/feature hero headline |
| `display.medium` | 30 px | 600 | 1.15 | Screen headline |
| `heading.large` | 24 px | 600 | 1.2 | Major section title |
| `heading.medium` | 20 px | 600 | 1.25 | Card or subsection title |
| `body.large` | 18 px | 400 | 1.45 | Important explanation and safety instructions |
| `body` | 16 px | 400 | 1.5 | Default body text |
| `body.strong` | 16 px | 600 | 1.35 | Emphasis and important values |
| `label` | 14 px | 500 | 1.35 | Controls, metadata labels |
| `caption` | 12 px | 400 | 1.4 | Secondary metadata only |

Rules:

- Do not make essential emergency instructions smaller than 16 px.
- Avoid long all-caps labels. Use sentence case.
- Use restrained negative tracking only for large display headings; body and labels use normal tracking.
- Avoid ultra-light text weights on critical information.
- Support system text scaling and prevent clipped labels.
- Use tabular numerals for distance, capacity, time, and other changing numeric values when supported.

## 6. Layout, spacing, and geometry

### 6.1 Spacing scale

Use an 8 px base rhythm with 4 px refinements:

`4, 8, 12, 16, 24, 32, 40, 48, 64` px.

- Screen horizontal padding: typically 20–24 px on phones.
- Standard section gap: 24–32 px.
- Large editorial section gap: 40–48 px.
- Card internal padding: 16–24 px depending on content density.
- Keep content away from device cutouts and system navigation areas using safe areas.

### 6.2 Radius scale

| Token | Radius | Use |
|---|---:|---|
| `radius.flat` | 0 px | Full-bleed map and editorial bands |
| `radius.input` | 8 px | Text fields and compact controls |
| `radius.card` | 12 px | Standard cards and imagery |
| `radius.panel` | 16 px | Large sheets and modal panels |
| `radius.pill` | 999 px | Primary CTA, filter chips, compact status chips |
| `radius.circle` | 50% | Icon controls and markers |

Use a small, consistent radius vocabulary. Do not round every container differently.

### 6.3 Elevation and borders

- Default cards are flat on the canvas with no resting drop shadow.
- Use surface contrast first, then a subtle `#E2E8F0` hairline only when separation is needed.
- Use elevation sparingly for transient sheets, dialogs, and controls floating over a map.
- Pressed states may use a small visual change; avoid large card-lift animations.
- Never use shadows to compensate for poor spacing or hierarchy.

## 7. Components

### 7.1 Buttons

**Primary button**
- Brand blue or deep-blue fill, white label, pill shape.
- Minimum height 48 px; aim for at least 48 × 48 px touch area.
- One primary action per content region where possible.
- Use concise action labels: "View route", "Find shelters", "Continue".

**Secondary button**
- Transparent or soft-surface fill, dark text, subtle outline if needed.
- Same height and radius language as primary.

**Destructive / emergency button**
- Critical red treatment reserved for SOS or destructive actions.
- Clearly state what will happen before launching an external call or action.
- Never make a decorative red button look like an active emergency control.

**Icon button**
- At least 44–48 px touch area.
- Provide semantic tooltip/accessible label.
- Do not use an icon alone when the action could be ambiguous.

### 7.2 Cards

- Use cards only to group information that belongs together.
- Prefer a clear title, short supporting line, and one obvious action.
- Avoid nesting cards inside cards.
- Avoid a dashboard made entirely of identical tiles; vary layout based on information priority.
- Sample or simulated data labels must remain visible within the relevant card.

### 7.3 Inputs and filters

- Clear labels, readable input text, visible focus state, and helpful empty/error states.
- Search should not obscure the map or essential content.
- Filter chips use pill geometry and a clearly distinguishable selected state.
- Do not rely on placeholder text as the only label.

### 7.4 Bottom navigation

The five primary tabs are fixed:

1. Home
2. Map
3. Evacuate
4. Shelters
5. Alerts

Rules:

- Keep labels visible; do not use icons alone.
- Clearly indicate the selected tab using both color and a selected-state treatment.
- Keep the bar consistent across the five screens.
- Respect safe-area insets and avoid content being hidden behind the bar.
- Do not add Profile or Settings as a sixth tab. Place secondary settings/profile access in the app header or a secondary screen.

### 7.5 Persistent SOS access

- SOS must be discoverable from every primary tab.
- It may be a persistent floating action or a clearly visible action in the app shell, but must not cover navigation, map controls, or critical text.
- Use red only for this emergency action and genuinely critical states.
- The button opens a confirmation/action flow appropriate to the implementation. Explain whether it opens the phone dialer, sends a message, or performs another action.
- Never claim that pressing SOS automatically alerts authorities unless that integration exists and has been tested.

### 7.6 Alerts and risk indicators

Every alert should show, where available:

- Severity label and icon.
- Alert title and concise description.
- Affected area.
- Source or origin.
- Timestamp and freshness/last-updated state.
- Recommended action or safety instruction.
- Whether the alert is sample/demo or from a connected source.

Do not invent an agency/source name. If no source is available, display "Source not provided" or omit the source field.

## 8. Five-tab screen specifications

### 8.1 Home — situational overview

**Purpose:** Answer quickly: Where am I? What information is available? What can I do next?

Suggested hierarchy:

1. Compact app header with SurakshaPath logo/wordmark and secondary profile/settings access.
2. Location row showing actual GPS status, selected/demo location, or a clear unavailable state.
3. One prominent situation/status area. Do not invent a current disaster status; show "No live alert source connected" or "Demo scenario" when appropriate.
4. Three direct actions: Map, Evacuate, Shelters.
5. Nearby shelter summary only when data exists, with its data status.
6. Latest alert preview with timestamp/source status.
7. Persistent SOS access.

Visual direction: Apple-like information clarity, a single restrained brand hero, Tesla-like whitespace. Avoid filling the screen with decorative statistics or unsupported safety scores.

### 8.2 Map — geographic context

**Purpose:** Show the user's location and available geographic information.

- Map is the dominant surface.
- Provide a clear current-location control and search/location context.
- Use consistent map markers for shelters, hazards, and user location.
- Include a compact legend that can be expanded or collapsed.
- Selected marker opens a bottom information sheet with name, type, data status, and available details.
- Use a visible offline/unavailable state if tiles or location cannot load.
- Distinguish known hazard overlays from illustrative/demo overlays.
- Never label an area safe merely because no hazard marker is shown.

Map marker semantics:
- User location: blue location marker.
- Shelter: green marker only when availability is supported; otherwise neutral marker with explicit status.
- Hazard: red/orange/yellow based on supplied severity.
- Unknown/unverified: neutral gray marker.

### 8.3 Evacuate — route decision support

**Purpose:** Help users inspect route options and relevant warnings without overstating safety.

Suggested hierarchy:

1. Starting location and destination.
2. Suggested route and alternate route, if available.
3. Distance and estimated time with units and calculation/source context.
4. Known hazards or blocked-road information along the route.
5. Route data freshness and whether values are simulated.
6. Action to view route on the Map.

Use language such as "Suggested route", "Known hazard nearby", and "Route data may be incomplete". Never use "100% safe", "guaranteed safe", or "NDMA verified" without substantiation. Do not fabricate travel time, route risk scores, or road closures.

### 8.4 Shelters — discovery and capacity

**Purpose:** Let users inspect available shelter records and their details.

- Search and filter by distance/type/status only when those fields exist.
- Each shelter item can show name, distance, type, capacity/occupancy, and last-updated status when supplied.
- Capacity must distinguish total capacity, occupied count, and remaining capacity. Do not derive or display values if the required source fields are missing or inconsistent.
- Use "Availability unknown" when no reliable status is available.
- Clearly label local seed data as "Demo data".
- Shelter detail view should show location, available contact/details, and a map action when supported.

### 8.5 Alerts — alert center

**Purpose:** Present relevant warnings in a calm, ordered, actionable format.

- Sort by severity and then timestamp only when those values are known.
- Each alert shows severity, title, area, timestamp, source, and instruction where available.
- Separate active alerts from history.
- Show empty state when no alerts exist; do not invent an active emergency to make the screen look populated.
- Clearly label sample alerts.
- Provide an accessible alert detail view.

## 9. Motion and interaction

- Motion must communicate state, not decorate the screen.
- Use short, consistent transitions around 200–330 ms where appropriate.
- Prefer subtle fades, small position changes, and clear pressed states.
- Respect system reduced-motion settings.
- Do not auto-advance critical alerts or auto-dismiss emergency information.
- Do not use motion as the only indicator of loading, selection, or status.
- Avoid parallax, autoplay carousels, and elaborate transitions in emergency workflows.

## 10. Imagery and illustration

- Use imagery only when it helps explain a place, situation, or action.
- Use real, licensed, project-owned, or clearly illustrative assets.
- Do not use unrelated cinematic imagery as a substitute for actual map, shelter, or hazard information.
- Never use imagery that implies a specific disaster is currently occurring when it is not.
- Do not place essential text over busy photography without a reliable contrast treatment.
- Prefer the map itself over decorative map illustrations on the Map tab.

## 11. Data integrity and UI copy

### 11.1 Data labels

Use explicit labels such as:

- `Live data` only when a connected source is actually providing current data.
- `Demo data` for seeded/sample values.
- `Last updated: [time]` only when a real timestamp exists.
- `Location unavailable` when GPS permission/service is missing.
- `Availability unknown` when shelter capacity/status is not supplied.
- `Offline` when the app has detected loss of network connectivity or is using cached content.

Do not display a live-data badge based only on the fact that a screen refreshed.

### 11.2 Copy style

- Calm, direct, plain language.
- Short sentences and familiar words.
- State what is known and what is not known.
- Avoid dramatic, promotional, or fear-inducing language.
- Give one clear next action where possible.

### 11.3 Demo content

If sample content is required for a UI demonstration, use plausible but explicitly fictional records. Do not use real agency logos or names in a way that implies endorsement. Keep a persistent, visible demo label on the screen or individual data card.

## 12. Accessibility and resilience

- Minimum interactive target: 44 × 44 logical pixels; 48 × 48 preferred.
- Maintain readable contrast for normal and large text.
- Support text scaling without overflow or clipping.
- Give meaningful semantics/labels to icons and map markers.
- Do not communicate status through color alone.
- Keep primary actions reachable and consistently positioned.
- Handle loading, empty, error, permission-denied, offline, and stale-data states.
- Ensure critical content is not hidden by the bottom navigation or SOS control.
- Test on narrow screens and at larger system font sizes.

## 13. Flutter implementation guidance

1. Implement shared color, typography, spacing, radius, and component tokens in the existing theme/constants structure.
2. Reuse existing navigation and feature modules. Do not replace the app architecture to achieve a visual redesign.
3. Keep the five tabs and SOS access consistent across the app shell.
4. Use reusable widgets for buttons, status labels, alert rows, shelter cards, and section headers.
5. Keep UI presentation separate from services and data models.
6. Do not add a dependency solely for a visual effect without explaining why it is needed.
7. Do not rewrite team-owned shelter, emergency, map, routing, or data logic unless a specific integration defect is identified and explained.
8. Preserve existing routes, constructors, model fields, and service contracts unless the team approves a coordinated change.
9. Before editing, inspect the current project and identify the files that will change. Do not overwrite files blindly.
10. Implement one screen at a time and run `flutter analyze` and relevant tests after each meaningful change.

## 14. Responsive behavior

- Phone portrait is the primary target.
- Support small phones without horizontal overflow.
- Use scrollable content beneath fixed navigation where appropriate.
- Respect safe areas and keyboard insets.
- On tablets, allow wider content margins and two-column layouts only when they improve scanning; do not simply stretch phone cards.
- Map controls must remain reachable and must not overlap one another.

## 15. Design review checklist

Before marking a screen complete, verify:

- [ ] It follows the official SurakshaPath colors and type scale.
- [ ] It has a clear primary purpose and visual hierarchy.
- [ ] It does not contain unsupported claims or fabricated values.
- [ ] Demo/sample data is visibly labelled.
- [ ] Loading, empty, error, offline, and unavailable states are considered.
- [ ] SOS remains accessible and does not obstruct controls.
- [ ] Bottom navigation is consistent and the selected tab is clear.
- [ ] Text remains readable at larger font sizes.
- [ ] Touch targets are large enough.
- [ ] Existing functionality and team module contracts are preserved.
- [ ] `flutter analyze` and relevant tests pass.

## 16. Instructions for Antigravity and other coding agents

Treat this file as the source of truth for SurakshaPath visual design. Do not invent additional design systems or reinterpret the brand palette. Do not make unsupported claims or create fictional live information. If a design choice conflicts with emergency usability, accessibility, data integrity, or an existing working feature, follow the product principles in Sections 2 and 11.

**Work process:**

1. Inspect the current Flutter app and report the current screens, navigation, theme files, and feature files that would be affected.
2. Propose a screen-by-screen implementation plan referencing this document.
3. Wait for approval before broad changes.
4. Implement one screen or shared component at a time.
5. Preserve working code and existing module contracts.
6. Run analysis and tests; report actual results only.
7. List every changed file and any remaining limitations.

Do not claim a test, build, runtime, integration, API, GPS, offline, or device check passed unless it was actually executed and its result observed.

---

**End of SurakshaPath Design System v1.0**
