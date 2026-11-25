import fs from 'node:fs';
import path from 'node:path';
import { decodeShp, montageIndexed } from './art_lib.mjs';

export function loadBibShapes(input) {
  const sections = {};
  let current = '';
  for (const raw of fs.readFileSync(path.join(input, 'art.ini'), 'utf8').split(/\r?\n/)) {
    const line = raw.split(';')[0].trim();
    const header = line.match(/^\[([^\]]+)\]$/);
    if (header) { current = header[1].toUpperCase(); continue; }
    const bib = line.match(/^BibShape\s*=\s*(\S+)$/i);
    if (current && bib && !/^none$/i.test(bib[1])) sections[current] = bib[1].toUpperCase();
  }
  return sections;
}

// Bibs are static building parts. Bake them below each body/damage/shadow frame,
// so drawing, placement preview, pixel picking and footprint use one complete image.
// Always compose from the original MIX, never from an already composed PNG.
export function buildingSheet(body, image, bibs, findShape) {
  const cols = Math.min(12, Math.max(1, body.frames.length));
  const sheet = montageIndexed(body, cols);
  const metadata = {};
  // art.ini GACSPH_E/ED: Rate=0, Start=0/1, Shadow=yes. The front dome
  // is permanent structure, unlike the F/G/H charge effects. Include it in
  // the body so placement, picking and anchoring see the complete foundation.
  if (image.toUpperCase() === 'GACSPH') {
    const source = findShape('GACSPH_E');
    if (!source) throw new Error('Missing permanent Chronosphere dome GACSPH_E');
    const shape = decodeShp(source.buf);
    if (shape.width !== body.width || shape.height !== body.height ||
        body.frames.length !== 6 || shape.frames.length !== 4) {
      throw new Error('Unsupported Chronosphere body/dome frame layout');
    }
    const dome = montageIndexed(shape, cols, [0, 1, 1, 2, 3, 3]);
    for (let i = 0; i < sheet.indices.length; i++) {
      if (dome.indices[i] !== 0) sheet.indices[i] = dome.indices[i];
    }
    metadata.baked_layers = ['GACSPH_E'];
    metadata.baked_layer_source = `${source.mix}/GACSPH_E.SHP`;
  }
  const bib = bibs[image.toUpperCase()];
  if (!bib) return { sheet, metadata };
  const source = findShape(bib);
  if (!source) throw new Error(`Missing BibShape ${image}: ${bib}`);
  const shape = decodeShp(source.buf);
  if (shape.width !== body.width || shape.height !== body.height ||
      body.frames.length !== 6 || ![4, 6].includes(shape.frames.length)) {
    throw new Error(`Unsupported BibShape layout ${image}: body=${body.frames.length}, bib=${shape.frames.length}`);
  }
  const underneath = shape.frames.length === 6 ? montageIndexed(shape, cols) : montageIndexed(shape, cols, [0, 1, 1, 2, 3, 3]);
  const addedPixels = [];
  for (const rect of sheet.rects) {
    let added = 0;
    for (let y = rect.y; y < rect.y + rect.h; y++) {
      for (let x = rect.x; x < rect.x + rect.w; x++) {
        const pixel = y * sheet.width + x;
        if (sheet.indices[pixel] === 0 && underneath.indices[pixel] !== 0) {
          sheet.indices[pixel] = underneath.indices[pixel];
          added++;
        }
      }
    }
    addedPixels.push(added);
  }
  return { sheet, metadata: { ...metadata, bib, bib_source: `${source.mix}/${bib}.SHP`, bib_added_pixels: addedPixels } };
}

export function correctFactoryStructure(layer, frameCount) {
  if (!/^GAWEAP_[1-4]$/.test(layer.image) || frameCount !== 4) return;
  // These local SHPs have healthy/damaged frames followed by their shadows.
  // art.ini's door loop ranges refer to a different layout; do not play shadows.
  Object.assign(layer, { loopStart: 0, loopEnd: 0, frames: 2, shadow: true });
  layer.dmg = { image: layer.image, loopStart: 1, loopEnd: 1,
    rate: layer.rate, frames: 2, shadow: true };
}
