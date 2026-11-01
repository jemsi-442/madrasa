# Afaq report logo

`afaq-logo.png` is a high-resolution PDF embedding derivative of the user's
canonical `frontend/assets/3.svg`. Do not redraw or replace the logo.

Regenerate from the repository root with:

```sh
rsvg-convert -w 1200 -h 1200 frontend/assets/3.svg -o /tmp/afaq-logo-full.png
convert /tmp/afaq-logo-full.png -trim +repage backend/assets/branding/afaq-logo.png
```

Deploy `backend/assets` alongside the compiled backend. PDFKit uses this raster
derivative because it does not natively embed SVG. The original SVG is retained.
