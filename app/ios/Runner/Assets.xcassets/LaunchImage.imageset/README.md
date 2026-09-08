# Launch screen assets

**Do not edit these by hand, and do not drop images in from Xcode.**

`LaunchImage.png` and its `@2x`/`@3x` are drawn by `scripts/brandmark.py`, along with the
Android launch bitmaps, both launcher icon sets and the notification silhouette. They are the
same mark at different sizes, and `make splash-check` fails the build if any of them stops
being exactly what the generator draws — so an image dropped in here will be reported as a
file that is not what it should be, not silently kept.

    make brandmark

`flutter create` left these as 68-byte blanks and the storyboard behind them pure white. What
replaced them, and why the colour is `#0B0F0C`, is in `DESIGN.md` under *The mark, and the
first screen*.
