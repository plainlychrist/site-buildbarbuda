# 1 - Creation

The `original.pdf` was created with pen strokes in OneNote 2016.

# 2 - Conversion to SVG

The PDF was converted to SVG using https://inkscape.org/ (version 0.92 on Windows using the default settings).

The SVG was saved as `modification-2.svg`.

# 3 - Trimming and Centering

Using InkScape ...

Just grab the pen strokes:
1. Removed the text
2. Drew a rectangle around the pen strokes, with no Fill (Shift-Ctrl-F).
3. Selected the rectangle. Resized Page to Selection (Shift-Ctrl-R).

Make the picture square:
1. Selected all the objects (Ctrl-A)
2. Scaled them to Width=10cm by Height=10cm (Shift-Ctrl-M).
3. Resized Page to Selection (Shift-Ctrl-R).

Make pen strokes bigger:
1. Selected all the objects (Ctrl-A)
2. Scaled them to Width=180% by Height=180% (Shift-Ctrl-M), with **Apply to each object separately** selected
3. Resized Page to Selection (Shift-Ctrl-R).

Get rid of all extraneous objects:
1. Object > Objects...
2. Every object that does not fit (there are a few extra objects by the cross, and there is a rectangle border that will be hard to see) should be removed. You have a tiny eye icon to the left of each object that will make it visible or invisible. Just start with all of them invisible, and turn on each object one at a time. If the object is a big pen stroke, keep it; otherwise press Delete.

Make the picture square:
1. Selected all the objects (Ctrl-A)
2. Scaled them to Width=10cm by Height=10cm (Shift-Ctrl-M).
3. Resized Page to Selection (Shift-Ctrl-R).

The SVG was saved as `modification-3.svg`

# 4 - Conversion to ICO

We need an icon file (actually several) so our logo appears in browser tabs. We use `#ffc40d` as the background color since it is one of the Windows Metro predefined colors (so it looks similar on all platforms).

1. Upload `modification-3.svg` to http://realfavicongenerator.net/
2. Set `Favicon for iOS - Web Clip`:
  * `Add a solid, plain background to fill the transparent regions.`
  * Background = `#ffc40d`
3. Set `Favicon for Android Chrome`:
  * `Add a solid, plain background to fill the transparent regions.`
  * Background = `#ffc40d`
  * App Name = `PlainlyChrist`
4. Set `Windows Metro`:
  * Use this color = `Yellow`
5. Set `Favicon Generator Options`:
  * `App Name: Specific app name, override the page title.`: `PlainlyChrist`

That produced `favicons.zip` and the following content for the `head` of each page:

```html
<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
<link rel="icon" type="image/png" href="/favicon-32x32.png" sizes="32x32">
<link rel="icon" type="image/png" href="/favicon-16x16.png" sizes="16x16">
<link rel="manifest" href="/manifest.json">
<link rel="mask-icon" href="/safari-pinned-tab.svg" color="#5bbad5">
<meta name="apple-mobile-web-app-title" content="PlainlyChrist">
<meta name="application-name" content="PlainlyChrist">
<meta name="theme-color" content="#ffc40d">
```

# 5 - Main Logo

Using InkScape ...

Make the picture 32x32:
1. Load `modification-3.svg`
2. Selected all the objects (Ctrl-A)
3. Scaled them to Width=32px by Height=32px (Shift-Ctrl-M).
4. Resized Page to Selection (Shift-Ctrl-R).

The SVG was saved as `modification-5.svg`
