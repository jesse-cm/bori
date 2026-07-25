/* bori-screen.js — dependency-free port of the Claude Design dot renderer.
 * Renders Bori as a dot-matrix bitmap into a .screen element.
 * No React, no framework: plain DOM. Pairs with theme.css.
 *
 * Usage:
 *   renderBori(el, 'sleep');   // session running
 *   renderBori(el, 'sit');     // idle
 */

// Bitmaps from the design export (20 x 14 logical grid, cells pre-doubled).
// '#' lit cream dot, 'o' eye (unlit, fills on blink), 'z' amber, '.'/'x' unlit
const BORI = {
  sit: [
    '....................####......####......',
    '....................####......####......',
    '..................########..########....',
    '..................########..########....',
    '..................##################....',
    '..................##################....',
    '................######oo######oo######..',
    '................######oo######oo######..',
    '................######oo##xx##oo######..',
    '................######oo##xx##oo######..',
    '................######################..',
    '................######################..',
    '..................##################....',
    '..................##################....',
    '....................##############......',
    '....................##############......',
    '..............####################......',
    '..............####################......',
    '........############################....',
    '........############################....',
    '......##############################....',
    '......##############################....',
    '....################################....',
    '....################################....',
    '..######........########....########....',
    '..######........########....########....',
    '................########....########....',
    '................########....########....'
  ],
  sleep: [
    '....##........##..........zz............',
    '....##........##..........zz............',
    '..########..########..zz................',
    '..########..########..zz................',
    '..##################....................',
    '..##################....................',
    '######################..................',
    '######################..................',
    '####xxxx####xxxx######..................',
    '####xxxx####xxxx######..................',
    '##########xx##########..................',
    '##########xx##########..................',
    '######################..##############..',
    '######################..##############..',
    '..##################....################',
    '..##################....################',
    '....##############..####################',
    '....##############..####################',
    '........################################',
    '........################################',
    '......##################################',
    '......##################################',
    '........##############################..',
    '........##############################..',
    '..................................######',
    '..................................######',
    '..........############################..',
    '..........############################..'
  ]
};

function renderBori(el, pose, opts = {}) {
  const pitch = opts.cellPitch ?? 4;     // px per cell
  const gap = opts.cellGap ?? 0.8;       // gap between dots
  const rows = BORI[pose];
  if (!rows) throw new Error('pose must be "sit" or "sleep"');

  const wrap = document.createElement('div');
  const w = rows[0].length * pitch, h = rows.length * pitch;
  wrap.style.cssText =
    `position:absolute;left:50%;top:50%;width:${w}px;height:${h}px;` +
    `transform:translate(-50%,-50%);` +
    (pose === 'sleep' && (opts.breathing ?? true)
      ? 'animation:bori-breathe 3.6s ease-in-out infinite;' : '');

  const frag = document.createDocumentFragment();
  rows.forEach((row, r) => {
    for (let c = 0; c < row.length; c++) {
      const ch = row[c];
      if (ch === '.' || ch === 'x') continue;
      const d = document.createElement('div');
      let bg = 'var(--screen-cream)', anim = '';
      if (ch === 'o') { bg = 'transparent'; anim = 'bori-blink 6.4s ease-in-out infinite'; }
      if (ch === 'z') {
        bg = 'var(--screen-amber)';
        anim = 'bori-z 3.2s ease-in-out infinite';
        if (r < 2) d.style.animationDelay = '0.6s';
      }
      d.style.cssText +=
        `position:absolute;left:${c * pitch}px;top:${r * pitch}px;` +
        `width:${pitch - gap}px;height:${pitch - gap}px;` +
        `background:${bg};` + (anim ? `animation:${anim};` : '');
      frag.appendChild(d);
    }
  });

  wrap.appendChild(frag);
  el.replaceChildren(wrap);
}

if (typeof module !== 'undefined') module.exports = { renderBori, BORI };
