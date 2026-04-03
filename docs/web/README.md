# AIOS-Lite Web Documentation Site

> © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal

This directory contains the web presence content for AIOS-Lite, ready for deployment on
GitHub Pages, Netlify, Vercel, or any static hosting provider.

---

## Site Structure

```
docs/web/
├── README.md              ← This file — site structure overview
├── index.md               ← Landing page (home)
├── getting-started.md     ← Getting Started guide
└── api-reference.md       ← API Reference web page
```

---

## Pages

| File | URL slug | Description |
|------|----------|-------------|
| `index.md` | `/` | Project landing page — hero, features, quick install |
| `getting-started.md` | `/getting-started` | Step-by-step setup for new users |
| `api-reference.md` | `/api-reference` | Complete HTTP API reference for developers |

---

## Deployment Options

### GitHub Pages

1. Enable GitHub Pages in repository Settings → Pages
2. Set source to `docs/` folder on the `main` branch (or use a `gh-pages` branch)
3. Add a `_config.yml` for Jekyll (optional) or use a static HTML generator

### Netlify

1. Connect the GitHub repository to Netlify
2. Set **Publish directory** to `docs/web`
3. Netlify will serve Markdown automatically if paired with a static site generator (Hugo, Eleventy, MkDocs)

### Vercel

1. Import the GitHub repository in Vercel
2. Choose a framework (e.g., Next.js MDX, Docusaurus, or plain static)
3. Set the output directory to `docs/web`

### MkDocs (recommended for full docs site)

```yaml
# mkdocs.yml (place in repo root)
site_name: AIOS-Lite
site_description: AI-Augmented Portable Operating System
site_author: Chris Betts
site_url: https://docs.aios.example.com

docs_dir: docs/web
theme:
  name: material
  palette:
    primary: indigo
    accent: cyan
  features:
    - navigation.instant
    - navigation.tabs
    - search.highlight

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - API Reference: api-reference.md

extra:
  social:
    - icon: fontawesome/brands/github
      link: https://github.com/Cbetts1/PROJECT
```

```sh
pip install mkdocs mkdocs-material
mkdocs build   # output: site/
mkdocs serve   # local dev server at http://127.0.0.1:8000
mkdocs gh-deploy  # deploy to GitHub Pages
```

---

## SEO Configuration

Add a `<head>` section to your static site generator template with:

```html
<meta name="description" content="AIOS-Lite — AI-Augmented Portable Operating System. Run your AI OS on any device: Android, Linux, macOS, Raspberry Pi.">
<meta name="keywords" content="AI OS, AIOS, portable operating system, LLaMA, AI shell, cross-platform, Termux, Raspberry Pi">
<meta property="og:title" content="AIOS-Lite — AI-Augmented Portable OS">
<meta property="og:description" content="Plug your OS into any device and your system mirrors it — AI-powered, portable, and open.">
<meta property="og:image" content="https://aios.example.com/og-image.png">
<meta property="og:url" content="https://aios.example.com">
<meta name="twitter:card" content="summary_large_image">
<link rel="canonical" href="https://aios.example.com">
```

---

*Last updated: 2026-04-03*
