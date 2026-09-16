# Devon Kubacki — Portfolio

Static site: plain HTML, one stylesheet, one script, no framework. Live at
[devonkubacki.com](https://devonkubacki.com) (Netlify, from `main` on
[github.com/devon1137/portfolio-site](https://github.com/devon1137/portfolio-site)).

There is no build step for the *site* — every page is committed as finished HTML — but the
pages that repeat (case studies, writing samples, the Gallery, the nav submenus, the header and
footer, the sitemap) are **generated from sources in `tools/`**. Edit the source, run the build,
commit the result. Editing generated HTML by hand gets overwritten on the next build.

## What's here

| Page | What it is |
|---|---|
| `index.html` | Home: hero stats, What I Actually Do, Recent Work, Track Record, testimonial, Foundation Package band |
| `about.html` | Timeline and skills |
| `projects.html` | **Work** index (case studies grouped by category) — "projects" is the historical filename |
| `work/<slug>/index.html` | Ten case studies, **generated** from `tools/work-src/<slug>.html` |
| `writing.html`, `writing/<slug>/index.html` | Writing samples (articles + fiction), **generated** from `tools/writing-src/` |
| `gallery.html` | One band of screenshots per case study, **generated** from the case-study sources |
| `services.html` | Foundation Package ($2,000, WordPress) and Launch Package ($1,500, hand-coded), How It Works, terms, FAQ, by-quote services |
| `agreement.html` | The signable contract for both packages (`noindex`, not in the nav) |
| `questionnaire.html` | The client intake questionnaire, sent after signing (`noindex`, not in the nav) |
| `resume.html` + `Devon-Kubacki-Resume.pdf` | Resume page; the PDF is printed from it |
| `contact.html`, `privacy.html`, `terms.html`, `sitemap.html`, `404.html` | The rest |
| `sitemap.xml`, `robots.txt`, `_headers` | Generated sitemap, robots, Netlify security headers |

Four categories of work run through everything: web development, SEO & content, sales, and
marketing & operations.

## Building

```powershell
.\tools\build.ps1
```

That's the one command. In order it runs:

1. `sync-chrome.ps1` — stamps the shared header and footer (`tools/chrome/header.html`, `footer.html`)
   into every page, then `sync-nav.ps1` fills the Work and Writing submenus from the sources.
2. `build-work.ps1` — `work/<slug>/index.html` from `tools/work-src/`, in `tools/work-order.txt` order.
3. `build-writing.ps1` — `writing/<slug>/index.html` and the list on `writing.html`, in `tools/writing-order.txt` order.
4. `build-gallery.ps1` — Gallery bands from the case studies' own gallery sections.
5. `build-sitemap.ps1` — `sitemap.xml` (and the `Sitemap:` line in `robots.txt`).
6. `sync-chrome.ps1 -Check` — fails if anything is still out of sync.

Everything is PowerShell 5.1 and headless Edge; no Node, Python, or ImageMagick needed on Windows.

### Adding a case study

1. Write `tools/work-src/<slug>.html`: a JSON `<!--meta … -->` block (slug, title, category, dates,
   lede, description, role, timeline, stack, links, group) followed by top-level `<section>`s with
   `data-title` for the table of contents. Copy an existing one; `build-work.ps1`'s header documents every field.
2. Add the slug to `tools/work-order.txt` where it should appear.
3. Drop images in (see below), run `.\tools\build.ps1`, commit `tools/`, `work/`, `gallery.html`,
   `sitemap.xml`, and the pages the nav sync touched.

Writing samples work the same way with `tools/writing-src/`, `tools/writing-order.txt`, and
`build-writing.ps1` (fields: kind, source, published, archived, case, note, content).

### Things not in `build.ps1` (binaries that only change when their source does)

- `build-resume.ps1` — prints `resume.html` to `Devon-Kubacki-Resume.pdf`. Run after editing the resume.
- `build-og.ps1` — renders `tools/og-card.html` to `images/og-card.jpg`. Run after a palette change.
- `build-card.ps1` — the business card PDF from `tools/business-card.html`.
- `build-qr.ps1` — `images/venmo-qr.svg` from the `venmo` value in `tools/site.json` (the app's own QR URL).
  The agreement's two pay links carry the same URL by hand. Run after changing it.

All three need the **local preview server running** (below) so the site stylesheet resolves.

### Images

`images/` holds WebP only, three sizes per picture: `name.webp` (1440w, used by the lightbox),
`name-960.webp` (main slots), `name-480.webp` (thumbnails, phones).

- `tools/import-images.ps1 -Map @{ 'slug-name' = 'C:\path\to\original.jpg' }` converts originals to
  WebP at a capped width (add `crop = 'x,y,w,h'` to crop first).
- `tools/resize-images.ps1` makes the 960/480 variants; re-runnable, skips anything up to date.

Aim for under ~100KB per file; a handful of ad captures are the only ones above 200KB.

## Origin and domain

`tools/site.json` holds the public origin. Canonical URLs, `og:image`, `sitemap.xml`, and the
robots `Sitemap:` line all key off it. It is `https://devonkubacki.com`; the build stamps it into every page.

## Deploying

Netlify builds from `main` automatically — no build command, publish directory is the root.

**Deploys cost credits.** Each production deploy (git push *or* drag-and-drop) consumes plan
credits, and running out pauses deploys until the next cycle while the last build stays live.
Batch changes and push once; preview locally in between. `_headers` sets the security headers and
marks the agreement `noindex`.

## The agreement form (`agreement.html`)

One form covers both packages (a `package` radio picks Launch or Foundation). Submissions go through
**Netlify Forms**. Two things have to be true for it to work:

1. **Form detection is enabled** in the Netlify dashboard (*Site configuration → Forms → Enable
   form detection*). It's opt-in, and it only takes effect on the next deploy. Until then, POSTs
   return 404 and the form shows its "email the signed page" fallback.
2. *Site configuration → Notifications → Form submission notifications* has an email notification to
   devon.kubacki@gmail.com, so each signed agreement lands in the inbox.

Each submission includes the package, business name, email, phone, the agree, footer-credit and own-copy discount and
portfolio-opt-out checkboxes, printed name, typed signature, the date they picked, `signed_at`
(a UTC timestamp set on submit), and `countersign_url` — a link that reopens the page in
**countersign mode** with every answer prefilled and locked, Devon's signature and the effective
date as inputs, and Print / Save as PDF as the only action. Open it from the notification email,
sign, set the date, print to PDF, email the client. The prefill lasts seven days from the
client's signature; after that the link opens countersign mode empty (the submission is still in
the Netlify Forms dashboard). Clients type their email twice; the success message echoes it back. A honeypot field (`bot-field`) filters basic spam.

**Changing the terms:** the numbers on `services.html` (prices, deposit split, the footer-credit and own-copy discounts,
$60/hour, restart and cancellation fees) mirror the agreement's Section 3, and the How It Works
steps mirror its timeline clauses. Change a term in one place, change it in the other.

**Locally**, the preview server answers POSTs with 200 so the success state can be exercised; nothing is stored.

## The questionnaire (`questionnaire.html`)

The intake form the agreement's success message links to (carrying `?package=`). Eleven sections of
questions, most of them optional textareas, on the same Netlify Forms path as the agreement (form
name `questionnaire`, so the same form-detection and notification setup covers it). A "recorded
call" option in Section 1 swaps the questions for a booking block (phone or video, three date and
time-of-day preferences, notes, a recording-consent box); the hidden half's fields are disabled so a
submission carries only the chosen half. The questions are the interview script either way, and a
blank print of the written version works as one. No calendar link yet; the email from the form is the
booking. Every answer box has an example placeholder from one made-up plumbing business. The blog section (10)
only shows for the Foundation Package. Linked from the agreement and mentioned in Services' How It
Works step 2; `noindex`, disallowed in `robots.txt`, skipped by the sitemap.

## Local preview

`file://` won't load the stylesheet in some sandboxes, and the build scripts need a real origin,
so run the static server:

```powershell
powershell -ExecutionPolicy Bypass -File .claude\serve.ps1
```

It serves the site at `http://localhost:8765` with Netlify-style pretty URLs and `404.html` for
misses. In the Claude desktop app, `.claude/launch.json` starts it via the preview pane. Both files
are tracked; the rest of `.claude/` is ignored.

## Design system notes

`css/style.css` is organized as tokens → base → layout → components → footer.

- **Three grounds, one accent.** Stone (`--ink`, warm charcoal) is the neutral body band; the hero,
  page intros, and `.on-pine` bands are forest green; `.on-slate` bands are desert earth; the
  footer is deep water with animated caustics. Gold (`--amber`) is the only accent. Every
  text/ground pair passes AAA (≥ 7:1).
- **Surface tokens flip per band.** Components only reference `--surface`, `--surface-2`, `--text`,
  `--text-dim`, `--line`, and `--accent`; wrapping a band in `.on-pine` or `.on-slate` swaps the
  whole palette with no per-component overrides.
- **Honeycomb texture** is drawn on `.grid-bg::before` and drifts with scroll (scroll-driven
  animations, with a static fallback). The hero adds blinking hex outlines from `script.js`.
- **Card hovers**: `.hex-card` (Recent Work, Foundation Package) wipes a lit honeycomb in from the edge
  the pointer entered and out toward the edge it left; `.orbit-card` (What I Actually Do) runs a
  meteor round the border and detonates it where the pointer leaves. Both are driven by the phase
  classes `is-lit` / `is-leaving` that `script.js` sets.
- **Type and space are fluid** (`--step-*`, `--space-*`), 360px → 1240px. No inline styles.
- **System fonts only** — serif headings (Georgia first), sans body — both tokens at the top of the stylesheet.
- `prefers-reduced-motion` collapses every animation site-wide.

## Structure

```
index.html, about.html, projects.html, services.html, agreement.html, questionnaire.html, gallery.html,
writing.html, resume.html, contact.html, privacy.html, terms.html, sitemap.html, 404.html
work/<slug>/index.html          generated case studies
writing/<slug>/index.html       generated writing samples
css/style.css  js/script.js
images/                          WebP, three sizes each
Devon-Kubacki-Resume.pdf, Devon-Kubacki-Business-Card.pdf
sitemap.xml, robots.txt, _headers
tools/
  build.ps1                      the one command
  sync-chrome.ps1, sync-nav.ps1  header/footer + submenus  (sources: tools/chrome/)
  build-work.ps1                 case studies              (sources: tools/work-src/, work-order.txt)
  build-writing.ps1              writing samples           (sources: tools/writing-src/, writing-order.txt)
  build-gallery.ps1, build-sitemap.ps1
  build-resume.ps1, build-og.ps1, build-card.ps1   binaries, run on demand
  import-images.ps1, resize-images.ps1
  site.json                      public origin
.claude/serve.ps1, launch.json   local preview server
```
