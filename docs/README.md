# ft8

8x8 tty font utility. Includes some bmp image handling and scripts to generate resized variations of a joj font, for use in the linux console.

### joj fonts

jojft is an image format I made up. Basically, it stores 8x8 glyphs into 1 bit per pixel, totaling 64 bits per glyph.

The default font `lycon` is provided with this repo, both because it's a backup for my own font and to demonstrate usage:

```bash
ft8 8,16,24 ~/AR/ft8/lycon ~/AR/ft8/fonts

```

Outs 8x8, 16x16 and 24x24 versions of `lycon` to the `ARPATH` font directory.

For more information on how to work with `AR` packages, refer to the [avtomat](https://github.com/Liebranca/avtomat) repository, where the example script `AR-install` demonstrates it in detail.

# TODO

- frontend for jojft unpack
- dedicated jojft editor
