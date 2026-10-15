# WhereIF — onboarding illustrations

Generated with the built-in image_gen tool via the imagegen skill. No CLI/API fallback.
Use case: illustration-story. The first supplied reference guides the vivid outlined 2D art;
the second guides the gradients, organic white sections and black circular arrow in Flutter.
PNG alpha is preserved. UI copy is drawn by Flutter, not baked into the artwork.

## Final workspace assets

- [campus.png](C:/Users/Marce/auth_injustice/assets/onboarding/campus.png)
- [agenda.png](C:/Users/Marce/auth_injustice/assets/onboarding/agenda.png)
- [hours.png](C:/Users/Marce/auth_injustice/assets/onboarding/hours.png)

Implementation: lib/authentication/presentation/widgets/campus_onboarding.dart.
Copy: lib/core/l10n/app_pt.arb, app_en.arb, app_es.arb.
Completion is saved only by the final arrow on the real first-run flow. Skip goes
to the last page without saving. Settings replay returns to its caller without
writing preferences; existing first-run and authenticated-startup routing remain.
Motion: first entry 1000ms: illustration begins at 120ms, card at 370ms,
text at 500ms and controls at 650ms. No initial blank delay. Page slide 420ms,
later illustration reveal 620ms,
exit 280ms, arrow press 130ms. System reduced-motion preference is respected.
Normal page changes use only the arrow; dragging and progress-dot shortcuts are
disabled. Copy is measured and its font size reduced to fit without vertical
scrolling. Text exits upward with a 230 ms fade during the page transition,
then the next step enters from above with the event page's 450 ms slide/fade.
Every step restarts its text entrance, including already-built pages. Both themes
use gradients derived from the app's primary, secondary and error colors.
PNG decode width is bounded to 720–1280 pixels and current/next art is prewarmed.


## campus.png

Create one polished production illustration for a Brazilian university campus onboarding. Style: vivid 2D editorial comic art, confident dark navy ink outlines, flat saturated coral pink, violet, lavender and cyan, slightly hand-drawn lively shapes, intricate but clear, inspired by bold contemporary illustrated onboarding artwork, NOT 3D, NOT clay, NOT photorealistic, NOT generic thin-line icons. Cohesive collection of three illustrations. Use crisp ink details, playful little starbursts and orbit marks, a little fine paper texture INSIDE colored forms only. Transparent alpha background. Standalone isolated art only; no phone, no full UI, no outer background, no words, no letters, no watermarks. Composition centered with comfortable transparent margins; occupy 85% of a square canvas. High quality clean edges for scaling on mobile. Subject: a beautiful compact isometric two-story modern university building with a long horizontal facade, dark blue windows, coral facade details, lavender roof and steps, one small tree, a flowing cyan pathway curving toward the viewer, and a large vivid pink location pin hovering above the building. Include a small student with a coral backpack near the entrance as scale, faceless simplified. Give the building a bold diagonal perspective. Leave upper-right corner mostly transparent for an actual event popup to be added by application code. Art must be rich and intentionally designed, not a map screenshot. Building and route are the heroes.

## agenda.png

Create one polished production illustration for a Brazilian university campus onboarding. Style: vivid 2D editorial comic art, confident dark navy ink outlines, flat saturated coral pink, violet, lavender and cyan, slightly hand-drawn lively shapes, intricate but clear, inspired by bold contemporary illustrated onboarding artwork, NOT 3D, NOT clay, NOT photorealistic, NOT generic thin-line icons. Cohesive collection of three illustrations. Use crisp ink details, playful little starbursts and orbit marks, a little fine paper texture INSIDE colored forms only. Transparent alpha background. Standalone isolated art only; no phone, no full UI, no outer background, no words, no letters, no watermarks. Composition centered with comfortable transparent margins; occupy 85% of a square canvas. High quality clean edges for scaling on mobile. Subject: an expressive oversized standing desk calendar in three-quarter perspective with a violet outlined frame, coral pink upper band, round binding rings, cream face, empty lavender rounded date squares and a few cyan checked squares, NO numbers or letters. A big golden-coral notification bell swooshes across the upper-right front with a small pink unread bubble and violet ringing arcs. Behind it is an abstract cyan ribbon/orbit; in front a tiny check badge and one small starburst. Bold asymmetric dynamic composition, calendar and bell are equally clear, whimsical yet premium editorial design.

## hours.png

Create one polished production illustration for a Brazilian university campus onboarding. Style: vivid 2D editorial comic art, confident dark navy ink outlines, flat saturated coral pink, violet, lavender and cyan, slightly hand-drawn lively shapes, intricate but clear, inspired by bold contemporary illustrated onboarding artwork, NOT 3D, NOT clay, NOT photorealistic, NOT generic thin-line icons. Cohesive collection of three illustrations. Use crisp ink details, playful little starbursts and orbit marks, a little fine paper texture INSIDE colored forms only. Transparent alpha background. Standalone isolated art only; no phone, no full UI, no outer background, no words, no letters, no watermarks. Composition centered with comfortable transparent margins; occupy 85% of a square canvas. High quality clean edges for scaling on mobile. Subject: a beautiful open study log notebook in isometric three-quarter perspective, warm ivory pages, bold violet cover, coral pink spine, empty lavender rows with colorful cyan and pink check marks. A large violet and coral analog clock with clean dark hands and NO numbers floats behind it, and three small staggered colorful progress blocks rise upward on the right like a personal tally, with a subtle starburst. A coral pencil rests diagonally across notebook edge. Make it communicate recording activities and adding up time, not official certification, no trophy, diploma, money or graduation cap. Rich clear editorial art, notebook and clock heroes.
