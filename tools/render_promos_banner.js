/**
 * Rend assets/images/src/promos_banner.svg en assets/images/promos_banner.jpg.
 *
 * Le JPG est l'asset que Flutter embarque ; le SVG est la source qu'on édite.
 * Regénérer après chaque retouche du SVG :
 *
 *   npm install sharp        # une fois
 *   node tools/render_promos_banner.js
 *
 * JPEG et non PNG : la bannière est une illustration plein cadre de 1600×800,
 * en JPEG qualité 92 elle pèse quelques dizaines de kilo-octets contre plus
 * d'un demi-méga en PNG, pour une différence invisible à l'écran. Le fond est
 * aplati sur du marine plutôt que sur du blanc, au cas où le rendu laisserait
 * un bord transparent : une frange blanche se verrait, une frange marine non.
 */

const path = require('path');
const sharp = require('sharp');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'assets', 'images', 'src', 'promos_banner.svg');
const OUT = path.join(ROOT, 'assets', 'images', 'promos_banner.jpg');

const WIDTH = 1600;
const HEIGHT = 800;

sharp(SRC, { density: 144 })
  .resize(WIDTH, HEIGHT, { fit: 'fill' })
  .flatten({ background: '#0A1A4F' })
  .jpeg({ quality: 92, chromaSubsampling: '4:4:4', mozjpeg: true })
  .toFile(OUT)
  .then((info) => {
    console.log(`${path.relative(ROOT, OUT)} — ${info.width}x${info.height}, ${(info.size / 1024).toFixed(0)} Ko`);
  })
  .catch((err) => {
    console.error('Échec du rendu :', err.message);
    process.exit(1);
  });
