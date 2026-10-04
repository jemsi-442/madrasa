# Public Page Assets

## Media Player Samples

`media-preview/video.mp4` is an original 40-second silent animation generated
with ffmpeg and the bundled Noto Sans Display fonts. `audio.m4a` contains
low-volume synthetic tones, not a lesson recording. `guide.pdf` is a two-page
original player guide; `checklist.txt` is plain sample text. The image preview
reuses the illustration described below. These samples are bundled in web and
native builds and never create course, student or learning-progress records.

Regenerate the video, audio and PDF from `frontend/` with:

```bash
node tool/generate_media_preview.mjs
```

Generation requires ffmpeg with the H.264 encoder; running the app does not.

## Homepage Illustration

`learning-hero.png` was generated using the built-in `image_gen` tool for the public homepage. It is an illustrative scene, not a photograph of an enrolled student. The image is bundled locally and has no third-party branding.

Generation prompt:

Use case: photorealistic-natural. Asset type: website homepage hero photograph, landscape 3:2. A warm candid editorial photograph of a happy East African Muslim schoolboy, about 10 years old, wearing a clean white thobe and an embroidered white kufi, studying on an unbranded dark tablet at a wooden desk in a bright madrasa library. The boy is seated in the right two-thirds of the frame, smiling naturally while looking down at the tablet. A small stack of dark navy and tan books sits in the lower right foreground. Softly blurred bookshelves and other students far in the background, warm natural window light from the left, authentic skin and fabric textures, understated premium educational photography. Keep the left third light, softly defocused cream for a website text fade. Eye-level medium shot, natural proportions and hands. No text, no letters on books, no logos, no watermark, no UI, no browser or device frame. This is just the photograph to integrate into the app.
