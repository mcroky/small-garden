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
  // Cached HTML may still request its older pack after a new release.
  if (name === '.nojekyll' || name === 'preview.png' || /^index-[0-9a-f]{12}\.pck$/.test(name) || files.includes(name)) continue;
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
html = html.replace('<title>작은정원</title>', '<title>작은정원</title>\n\t\t<link rel="canonical" href="https://mcroky.github.io/small-garden/">\n\t\t<meta name="description" content="꽃을 심고 돌보며 나만의 3D 정원을 가꾸는 게임">\n\t\t<meta property="og:title" content="작은정원">\n\t\t<meta property="og:description" content="꽃을 심고 돌보며 나만의 3D 정원을 가꾸는 게임">\n\t\t<meta property="og:image" content="https://mcroky.github.io/small-garden/preview.png">\n\t\t<meta property="og:url" content="https://mcroky.github.io/small-garden/">\n\t\t<link rel="icon" href="index.icon.png">');
// Keep the exported game in its own viewport so the web link never covers controls.
// This wrapper is web-only; native Android exports do not include it.
writeFileSync(join(destination, 'game.html'), html.trimEnd() + '\n');
writeFileSync(htmlPath, "<!doctype html>\n<html lang=\"ko\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1,viewport-fit=cover\"><title>작은정원</title><meta name=\"description\" content=\"꽃을 심고 돌보며 나만의 3D 정원을 가꾸는 게임\"><link rel=\"canonical\" href=\"https://mcroky.github.io/small-garden/\"><link rel=\"icon\" href=\"index.icon.png\"><meta property=\"og:image\" content=\"https://mcroky.github.io/small-garden/preview.png\"><style>html,body{margin:0;height:100%;background:#eaf0e5;color:#254a3a;font-family:system-ui,sans-serif}body{height:100dvh;display:flex;flex-direction:column}iframe{display:block;flex:1;min-height:0;width:100%;border:0}nav{display:flex;justify-content:center;align-items:center;flex-wrap:wrap;gap:8px;padding:6px 12px max(6px,env(safe-area-inset-bottom))}nav a{box-sizing:border-box;min-height:44px;display:inline-flex;align-items:center;justify-content:center;padding:8px 14px;border:1px solid #a28a12;border-radius:9px;background:#ffe14c;color:#242000;font-weight:700;text-decoration:none;font-size:14px}nav a:focus-visible{outline:3px solid #2676c4;outline-offset:2px}</style></head><body><iframe src=\"game.html\" title=\"작은정원 게임 화면\" allow=\"autoplay; fullscreen\" allowfullscreen></iframe><nav aria-label=\"웹 공통 안내\"><a data-web-only-transfer href=\"https://mcroky.github.io/roky-studio/#bank-transfer\" target=\"_blank\" rel=\"noopener noreferrer\" aria-label=\"카카오뱅크 이체 안내 새 탭에서 열기\">카카오뱅크 이체 ↗</a></nav></body></html>\n");
writeFileSync(join(destination, '.nojekyll'), '');
console.log(`GitHub Pages 파일 ${files.length}개와 버전 패키지 ${packName}을 docs/에 준비했습니다.`);
