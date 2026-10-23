import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { basename, join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const source = join(root, 'build', 'web');
const destination = join(root, 'docs');
const preview = join(root, 'screenshots', 'web-wide.png');

if (!existsSync(join(source, 'index.html')) || !existsSync(join(source, 'index.wasm'))) {
  throw new Error('build/web에 Godot 웹 내보내기 파일이 없습니다. 먼저 Web 내보내기를 실행하세요.');
}

mkdirSync(destination, { recursive: true });
const files = readdirSync(source).filter((name) => !name.endsWith('.import'));
for (const name of readdirSync(destination)) {
  if (name === '.nojekyll' || name === 'preview.png' || files.includes(name)) continue;
  const target = join(destination, basename(name));
  rmSync(target, { force: true });
}
for (const name of files) copyFileSync(join(source, name), join(destination, name));
copyFileSync(preview, join(destination, 'preview.png'));

// GitHub Pages caches assets for several minutes. Give each game pack a new URL
// so a refreshed page cannot silently reuse older sounds or scripts.
const packBytes = readFileSync(join(source, 'index.pck'));
const packName = `index-${createHash('sha256').update(packBytes).digest('hex').slice(0, 12)}.pck`;
copyFileSync(join(source, 'index.pck'), join(destination, packName));

const htmlPath = join(destination, 'index.html');
let html = readFileSync(htmlPath, 'utf8');
const configLine = html.match(/^const GODOT_CONFIG = (.+);$/m);
if (!configLine) throw new Error('Godot 웹 설정을 index.html에서 찾지 못했습니다.');
const config = JSON.parse(configLine[1]);
const packSize = config.fileSizes?.['index.pck'];
if (typeof packSize !== 'number') throw new Error('Godot 웹 패키지 크기를 찾지 못했습니다.');
delete config.fileSizes['index.pck'];
config.fileSizes[packName] = packSize;
config.mainPack = packName;
html = html.replace(configLine[0], `const GODOT_CONFIG = ${JSON.stringify(config)};`);
html = html.replace('<html lang="en">', '<html lang="ko">');
html = html.replace('<title>작은정원</title>', '<title>작은정원</title>\n\t\t<meta name="description" content="꽃을 심고 돌보며 나만의 3D 정원을 가꾸는 게임">\n\t\t<meta property="og:title" content="작은정원">\n\t\t<meta property="og:description" content="꽃을 심고 돌보며 나만의 3D 정원을 가꾸는 게임">\n\t\t<meta property="og:image" content="https://mcroky.github.io/small-garden/preview.png">\n\t\t<meta property="og:url" content="https://mcroky.github.io/small-garden/">\n\t\t<link rel="icon" href="index.icon.png">');
writeFileSync(htmlPath, html);
writeFileSync(join(destination, '.nojekyll'), '');
console.log(`GitHub Pages 파일 ${files.length}개와 버전 패키지 ${packName}을 docs/에 준비했습니다.`);
