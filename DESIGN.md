# ChartAgent Design Contract

## 2026-08-16 Agent Studio Simplification

- The Agent Studio tab is roster-first: it shows the header and the five cards in `내 분석팀` only. The separate animated Live Preview surface and explanatory footer card are removed.
- Profile editing is limited to name, speaking style, and one of the fixed investment-decision concepts. Appearance is not user-editable; the stored appearance remains stable for history and API compatibility.
- The profile editor sheet uses the solid app canvas. It must not introduce a full-screen gradient or decorative background layer.

## 2026-08-15 Pre-council Continuity and Follow-up Chat

- The copy shown before the analysis response arrives is localized operational status copy, not model chain-of-thought and not a market conclusion. It must rotate through specific, non-repeating chart tasks and use neutral language until screenshot evidence is available.
- Provider completion may not snap agents directly from their workstations into the final council. One two-agent check and one three-agent challenge may replay actual server-returned meeting lines first; each participant walks to an open huddle point, faces the group, speaks, and returns before the full council begins.
- Pre-council huddles and final council entry share the existing sprite timeline. Changing phase never remounts the office, resets character coordinates, or teleports a seated sprite into a meeting pose.
- Speech bubbles measure their localized text and grow vertically within a capped readable width. They remain centered over the speaker and are visible only after a huddle has arrived, so Korean copy cannot be clipped or travel with a moving character.
- Market direction terms are localized at both generation and presentation boundaries. Korean output uses `매수 우위`, `매도 우위`, or `관망`; English `buy-side`, `sell-side`, and `WAIT` are never exposed in Korean UI even if a provider returns them.
- Follow-up opens as a chat-first full-height sheet. Conversation history owns the main surface, the composer stays fixed at the bottom, and agent switching is a compact menu in the header that does not discard prior turns.

## 2026-08-15 Crop, Council Focus, and Report Density

- Selecting a chart opens a native-style crop surface before analysis. It shows only `취소`, `이미지 크롭`, `확인`, the full image, and four visible corner handles. Dragging a corner resizes the crop and dragging inside moves it; ratio tabs, zoom sliders, grids, and reset controls are intentionally absent. The final cropped JPEG is the only image sent to analysis; the source remains available locally for another adjustment.
- The analysis room owns one continuous animation clock from image processing through meeting entry. Provider completion may change stage, bubble, and route state atomically, but it may not pause/restart the sprite timeline or remount the office.
- Debate focus alternates between a two-person challenge and a three-person review. The current speaker faces one listener; in a 2:1 exchange two listeners face that speaker. Non-participants keep their stable inward meeting orientation.
- Speech bubbles carry only the typed statement and tail. Decorative ellipsis dots are removed because they compete with the typing cursor and imply a second loading state.
- Result agent rows render a readable 52×60 pt character aligned to the agent identity block. The disclosure indicator is fixed to the row's bottom-trailing corner and remains stable as evidence expands.
- Result calls are concise and direct: direction or WAIT first, exact confirmation/invalidation second. Strong wording never upgrades screenshot evidence into certainty.

## 2026-08-15 Evidence Decision Report

- The loading room must speak immediately. While the server is decoding the image or waiting for AI output, one selected specialist at a time shows a short localized work-note bubble anchored above that agent. These notes describe the current operation (for example, comparing visible swing highs) and never fabricate a conclusion or expose hidden chain-of-thought.
- Analysis-to-result navigation is a stable crossfade. The report does not scale, lift, or move vertically during the handoff, and the research-room geometry remains fixed while headings or bubbles change.
- `판독 범위` is removed from the report. Evidence limits stay enforced by the model and appear only where a specific claim is unavailable; they are not promoted as a standalone section.
- Numeric `합의도` is retired. The lead card shows `현재 판단`, a plain-language stance, and a categorical `근거 강도` (약함/보통/강함) derived from the structured confidence value. No percentage is rendered as if it were a market probability.
- The report order is: chart evidence → current decision → confirmation/invalidation scenarios → visible structure → five agent opinions → optional news usage → input quality → follow-up. Each section answers a different user question and avoids repeating the same summary.
- Agent rows are titled `에이전트별 판단`. The collapsed state contains each specialist's actual thesis, not a description of what they inspected; expanding reveals only the screenshot evidence supporting that opinion.
- When news is enabled, the report states how many InsightSentry items were collected, how many were used, whether they reinforced/softened/changed/did not affect the chart decision, and which exact article titles were used. Unused headlines remain citations, not hidden reasoning inputs.
- The five specialist contracts are chart-specific: swing structure; candlestick and boundary patterns; visible price-action momentum; levels and invalidation; false-break and counter-scenario review. Every server-generated opinion must stay inside its assigned contract.

## 2026-08-14 Live Data and Failure States

- Production screens never render sample symbols, sample candles, sample news, or canned agent conclusions. Home and History show persisted user analyses or a purposeful empty state.
- A new analysis requires three verified inputs before its CTA enables: a selected image, an InsightSentry search result with an exchange-qualified code, and a timeframe.
- Upload validation failures stay on the upload surface. The invalid field or image panel carries the error, one concrete recovery action, and a retry affordance; the user is never dropped into an empty meeting room.
- Network/provider failure is distinct from invalid input. It preserves the chosen image, symbol, timeframe, and news option so retry does not require re-entry.
- During a live request, office motion visualizes server work but never invents conclusions. Evidence-specific bubbles begin only after the structured response arrives, then replay the returned meeting script before the result transition.
- Result, follow-up, recent analysis, and history screens share one persisted `AnalysisRecord`; there is no second UI-only result model.
- Follow-up questions are scoped to the selected agent and original result JSON. Loading, success, and recoverable failure are explicit states inside the sheet.

## 2026-08-14 Evidence-Bounded Analysis

- The default input contract is exactly one chart screenshot. The report may describe only directly visible price structure, readable labels, relative candle behavior, and indicators that are visibly present in that screenshot.
- Exact live prices, unseen timeframes, order flow, derivatives, on-chain data, probabilities, and indicator values are unavailable unless a future verified data source supplies them. The UI labels unavailable evidence instead of inventing it.
- “뉴스 반영” is an explicit opt-in analysis option. When enabled, news items must later carry source and timestamp metadata and remain supporting context; when disabled, no news-derived claim appears in the report.
- Results prioritize an observation summary, visible structure, confirmation/invalidation checklist, agent disagreements, input coverage, and optional news context. Indicator dashboards and multi-timeframe claims are removed from the screenshot-only flow.
- The round evidence table belongs to the research room, not the home office. It is hidden on Home and remains visible from the first analysis scan through the final meeting stage.
- Home agents use furniture-clear Manhattan routes through one central corridor. Their optional localized remarks appear one at a time, roughly once every 24 seconds, and remain anchored to the speaking agent.
- Workstation seating uses a low armless swivel seat so the dedicated sitting sprite stays readable; each seat anchor is optically centered per character.
- Analysis and result headers remain transparent over the shared app canvas so the top chrome and content read as one continuous background.
- Live meeting movement is clock-sampled inside the office timeline. Parent state never sends one animated start-to-end position transaction, and each sampled route leg changes only one axis.

## 2026-08-14 Orthogonal Council Motion

- Every runtime route is Manhattan-only. Characters finish one horizontal or vertical leg before beginning the next; defensive interpolation also converts malformed diagonal segments into two orthogonal legs.
- Meeting entry is a staggered procession rather than five synchronized transforms. Each agent stands, clears its chair, follows an individual collision-safe route, faces the table, and deposits one accent-coded evidence card.
- Devil's taller horned front/back frames are optically normalized around a fixed foot anchor so direction changes never resize the character.
- Name tags sit directly below the visible shoes. Selection is communicated by the role panel and accessibility state, never by a colored strip beneath the sprite.
- Agent descriptions expand to their intrinsic height inside the map panel and are never truncated to a fixed line count.

## 2026-08-14 Full-body Sprite Reset

This pass replaces every earlier code-drawn character silhouette and workstation seating rule.

- The supplied `codex-clipboard-8029bdef-2478-49c0-80f7-d5d745042282.png` reference is the proportion contract: a compact 2–2.5-head-tall full-body person with a head no larger than 38% of standing height, visible shoulders and torso, two arms and hands, two separated legs, and two shoes. A head plus a narrow colored bar is a failed character.
- Each of the five agents owns a dedicated 4×4 sprite atlas. Rows are front/back/left/right; columns are idle/walk-A/walk-B/sit. The runtime may crop these frames but may not rebuild the body from generic rectangles.
- Character identity must survive every direction: Trendy has a mint visor and blue outfit, Patty has a black bob and violet outfit, Momo has darker skin plus blue headphones and teal outfit, Gadi has a brown field cap plus coral armband and green outfit, and Devil has white hair plus amber horn accessories and a black outfit.
- Walking alternates opposing arms and legs at 5–6 fps while position interpolates independently on a 30 fps character-only timeline. World coordinates are never rounded during movement; pixel snapping applies to static art only.
- Side-profile walking uses two visibly different stride frames with separated shoes and opposing arm swing. Runtime inserts the neutral contact frame between strides so the gait reads as four steps instead of a two-frame foot swap.
- All five desks face north toward their monitors. Their chairs also face north: the seat is below the desk and the chair back is south/below the seated agent. A monitor and chair may never face opposite directions.
- Sitting uses the dedicated bent-leg rear frame on the visible north-facing chair. The chair remains a separate static entity, and its south-side backrest never covers the head, torso identity, or name label.
- Station coordinates are seat anchors, not open-floor standing points. The seated hips align to the visible chair seat; characters do not float below a chair or pass through its back.
- Runtime performance target is smooth iPhone motion: furniture remains a static canvas, sprite atlases are decoded once by the asset system, walk frames change discretely, and only the character transform updates continuously.
- Autonomous routes clear the chair laterally before entering the aisle, travel at distance-normalized speed, and remain inside the central walkable band; no free diagonal segment may cross a workstation footprint.

## 2026-08-14 Office Quality Pass 2

This pass supersedes the earlier character scale, workstation repetition, sitting silhouette, meeting formation, and bubble lifecycle rules.

- Office characters render at approximately 40×54 pt before the name tag. At phone density the face must visibly contain two eyes plus a nose/mouth mark; every character has a distinct hair/accessory silhouette, full arms, separated legs, and shoes.
- Standing, walking, and sitting must read as different silhouettes. Sitting lowers the hips into the chair, bends both legs, keeps the chair back visible behind the torso, and never resembles a standing sprite parked in front of a chair.
- The single floor remains, but workstations are deliberately asymmetric: short single-monitor desk, dual-monitor analyst desk, laptop desk, drawer desk, and lamp/notepad desk. Desk widths stay within 58–84 pt at the primary phone width.
- Desks, chairs, monitors, drawers, lamps, paper, plants, wall chart, clock, and cabinet remain independent visual entities. Each entity uses a shadow/body/highlight recipe on the 2 pt pixel grid; detail supports identification without becoming painterly.
- The central office contains a compact round evidence table. During meetings the five agents form a loose pentagon around it and face inward; they never form a straight line.
- Meeting travel uses per-agent waypoint routes through open corridors. Top agents leave below their chairs before turning; bottom agents back away below their desks, move through the center aisle, and only then approach the table. No route segment crosses a desk, chair, monitor, or table footprint.
- Speech is an event, not a continuously moving overlay. On speaker change, the old bubble is removed first, a short empty beat follows, and a new bubble begins typing above the new speaker. Bubble position is stored with that speaker and has animations disabled, so it cannot fly between heads.
- Home autonomous motion uses the same collision-safe waypoint vocabulary. Characters may sit, stand, or walk, but do not dance, bob, gesture, or animate without a destination.

## 2026-08-14 Minimal Office Reset

The previous high-detail generated characters, composite desks, multi-room floors, rug, conference furniture, bookshelf, coffee bar, and oversized chart display are rejected and must not appear in the office render path.

The user reference `codex-clipboard-d7f83443-f20f-4cc1-9751-5e3e8c5665b2.png` is now the strict spatial and pixel-density contract:

- One uninterrupted warm-brown tiled floor. No functional room colors, borders, rugs, or zone labels.
- Characters are tiny blocky sprites, approximately 24×34 pt before their name tag. Four or five flat colors per character, one-pixel facial marks, no detailed portrait styling.
- Allowed character motion is only four-direction walking, sitting, and standing up. No talking gesture, waving, dancing, reading, typing, bobbing, floating props, or continuous idle motion.
- Desks, chairs, monitors, plants, clocks, and cabinets are separate low-detail entities. A desk is a flat brown slab with square legs; a chair is a small block silhouette; a monitor is a dark rectangle. No combined workstation artwork.
- Home agents autonomously alternate between walking along short unobstructed routes, sitting at assigned chairs, remaining still, and standing. Movement must have an observable destination and may not pass through furniture.
- Meetings show only one active speech bubble at a time. Its tail is anchored to the active speaker's exact head point and follows that speaker. Bubbles never overlap one another because a second bubble is not rendered.
- Meeting agents walk to a loose central huddle and face inward. There is no oversized meeting table; the agents themselves are the focal point.
- The generated `Agent*.imageset`, `OfficeEntities.imageset`, and `ModularOfficeEntities.imageset` remain quarantined legacy assets and are not consumed by `PixelAgentView` or `PixelOfficeView`.

## 0. Reference log

- User references: `IMG_0930.PNG`, `IMG_0931.PNG` — exact product intent for a tall, explorable pixel trading office, Korean name tags, and a selected-agent role panel.
- Existing onboarding references: `온보딩/IMG_0908.PNG` through `IMG_0918.PNG` — geometry contract for segmented progress, full-canvas background, typography scale, and floating bottom CTA.
- Existing result references: `주요화면/IMG_0921.PNG` through `IMG_0927.PNG` — content coverage contract for bias, plan, levels, liquidity, risk, news, patterns, indicators, and follow-up questions.
- ZEP research: official ZEP Office describes avatar proximity as the trigger for conversation; its map editor and private-area documentation establish clear walkable corridors, object-rich rooms, spatial groupings, name labels, and brighter conversation zones.
- Generated reference: `Preview/Concept-Office.png` — selected visual contract for room density, furniture variety, character distinction, and a map-anchored agent panel.
- Generated reference: `Preview/Concept-Meeting.png` — selected visual contract for agents moving toward a round table, facing one another, anchored typing bubbles, and a research timeline.
- Generated reference: `Preview/Concept-Result.png` — selected visual contract for five visible disclosure rows and an evidence-dense report.
- Production character sheets: `ChartAgent/Assets.xcassets/Agent*.imageset` — each uses a 4×4 contract: front/right/back/left rows and idle/walk-A/walk-B/talk columns.
- Production entity sheet: `ChartAgent/Assets.xcassets/OfficeEntities.imageset` — sixteen independently placeable desks, displays, meeting furniture, equipment, and props.
- Interactive furniture sheet: `ChartAgent/Assets.xcassets/ModularOfficeEntities.imageset` — empty desks/tables, four chair directions, four monitor directions, and standalone desk props. Composite workstation art is not used for seats or interaction zones.

## 1. Direction

ChartAgent is a sober market-research terminal with a living 16-bit office inside it. The memorable moment is not a glow or card: five visibly different specialists leave their stations, walk in from different directions, face one another around a walnut conference table, and type their objections above their own heads.

The app chrome stays quiet and native. Pixel rooms carry the character: warm walnut macro/news zone, slate research zone, charcoal technical zone, cream library, cool server light, and small pools of practical light.

## 2. Tokens

### Color

- `canvas`: tinted near-black `#030708`
- `surface-1`: graphite `#0B0F12`
- `surface-2`: lifted graphite `#12171A`
- `stroke`: white at 10%
- `text-primary`: white
- `text-secondary`: white at 57%
- `mint`: evidence/confirmation `#2EF5B3`
- `coral`: invalidation/bearish `#FF4F6E`
- `amber`: wait/caution `#FFBA42`
- `cobalt`: information/research `#598FFF`
- `violet`: pattern specialist `#988CFF`
- Pixel materials: walnut, brass, navy tile, charcoal tile, parchment, moss green, monitor cyan.

### Type

- Product headings: system rounded/black, 29–36 pt, tight tracking.
- Korean body: system medium, 14–17 pt, natural semantic wrapping.
- Data/levels: monospaced bold with tabular numerals.
- Pixel map labels: system rounded black, 9–11 pt, white on near-black material.

### Space and shape

- Screen gutter: 20 pt.
- Report row gap: 8 pt; major sections: 18–22 pt.
- App cards: 18–22 pt radius; disclosure rows: 12–14 pt; pixel map: 22 pt.
- Pixel geometry snaps to a 2 pt base unit. Map furniture avoids antialiasing where possible.

### Depth

- App surfaces: low-contrast tinted layers with one rim stroke; avoid nested floating cards.
- Pixel rooms: three layers — shadow/collision footprint, material body, 1–2 px highlight. One warm top-left light source.

## 3. Layout contracts

### Onboarding

- Segmented progress floats over the same full-screen canvas.
- CTA overlays the canvas at the bottom; no material bar or separate background wrapper.
- Page replacement uses spring slide + fade. Internal content enters in staggered opacity/vertical motion.

### Office

- Map is the hero, not a decorative card.
- Functional zones are visually distinct and connected by walkable corridors.
- Characters always show Korean name tags anchored beneath their feet.
- Tapping an agent selects them and raises a compact role panel at the bottom of the map.

### Meeting

- Evidence scan begins at stations; agents then walk to five meeting positions.
- Final positions visibly face the table. At least two directions are visible at once.
- Current speech is typed character-by-character in a bubble whose tail is anchored over its speaker.
- The operational loading phase reflects real request state; after the response arrives, the returned meeting script is replayed with a skip affordance.

### Result

- Five opinions are visible vertically with disclosure controls; no horizontal carousel.
- Result covers consensus, conditional trade plan, multi-timeframe confluence, levels/liquidity, indicators, risk scenarios, data confidence, and education notice.
- Follow-up is one clear action. It opens an item-driven bottom sheet, then lets the user select exactly one agent and ask an independent question.

## 4. Motion

- Onboarding page: interactive spring, response 0.50, damping 0.86.
- Stagger: header 0 ms, primary content 70 ms, repeated rows 55 ms each, CTA 180 ms.
- Agent walking: actual X/Y interpolation between stations and meeting seats; two-frame leg/body bob; sprite direction is derived from motion vector.
- Talking: subtle two-frame mouth/waveform only after the character reaches the seat.
- Disclosure: spring expansion with stable parent layout.
- Respect Reduce Motion by using fade-only transitions and no continuous bob.

## 5. Reusable primitives and states

- `PrimaryButton`: enabled, disabled, pressed; floats directly on canvas.
- `AnimatedPageEntrance`: hidden, entering, settled.
- `PixelAgentView`: direction (`front/back/left/right`), motion (`idle/walk/talk/read/type`), two walk frames, selected ring, name tag.
- `PixelOfficeView`: office/meeting layout, station paths, selected agent, active speaker, typed bubble.
- `PixelEntity`: desk variants, monitor variants, chair directions, wall chart, risk console, bookshelf, coffee station, plant, server rack, round meeting table.
- `AgentDisclosureRow`: collapsed/expanded, stance, confidence, evidence, dissent.
- `AgentQuestionSheet`: compact agent switcher, persistent multi-turn chat, suggested prompts, fixed composer, loading, server response, recoverable error.

## 6. Accessibility and cognitive constraints

- Interactive targets are at least 44 pt outside the pixel map.
- Pixel characters have full accessibility labels and selection hints.
- Color never carries stance alone; labels and icons accompany it.
- Meeting progress uses named stages plus percentage; movement is explanatory rather than decorative.
- Korean phrases must not leave particles/endings orphaned on their own line.

## 7. Responsive behavior

- Primary target: 393–440 pt iPhone portrait.
- iPad uses the same content max width (680 pt); office expands only within that bound so entity scale remains coherent.
- Result sections switch from two columns to one where width would make Korean content cramped.

## 8. Accepted debt

- Generated full-screen concept images remain references and are never pasted as UI.
- Runtime sprite cropping is handled by `SpriteSheetViews.swift`, so the direction/motion API remains independent from the source sheet.
- Workstations are assembled at runtime from independent desk, chair, monitor, and prop entities. This keeps collision and front/back layering separable for later sit/turn/look interactions.
- Account authentication and cross-device history sync remain future work; analysis history is persisted locally on the device.
- Final hand-retouched production atlases can replace the generated sheets later without changing agent direction/motion APIs.

## 9. Localization contract

- English (United States) is the product fallback. Unsupported system languages resolve to `en-US`.
- Store locales are `en-US`, `ko`, `ja`, `de`, `fr-FR`, `es-MX`, `pt-BR`, `zh-Hant`, `id`, `th`, `zh-Hans`, `vi`, `it`, `tr`, `es-ES`, and `fr-CA`.
- French and Spanish preserve regional selection; Chinese preserves Simplified/Traditional script selection.
- All UI copy, including onboarding, analysis states, results, paywall, settings, errors, and relative dates, comes from `Localizable.xcstrings` under the selected app locale.
- Agent analysis and follow-up requests send the exact selected locale to the server. The server must answer entirely in that language while preserving the one-word market stance vocabulary.
- Brand names (`ChartAgent`, `ChartAgent PRO`) and market symbols are never translated. Entry, stop, target, stance, and trading terminology use reviewed financial-domain copy instead of generic commerce translations.
