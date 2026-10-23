import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
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

const htmlPath = join(destination, 'index.html');
let html = readFileSync(htmlPath, 'utf8');
html = html.replace('<html lang="en">', '<html lang="ko">');
html = html.replace('<title>작은정원</title>', '<title>작은정원</title>\n\t\t<meta name="description" content="꽃을 심고 돌보며 나만의 3D 정원을 가꾸는 게임">\n\t\t<meta property="og:title" content="작은정원">\n\t\t<meta property="og:description" content="꽃을 심고 돌보며 나만의 3D 정원을 가꾸는 게임">\n\t\t<meta property="og:image" content="https://mcroky.github.io/small-garden/preview.png">\n\t\t<meta property="og:url" content="https://mcroky.github.io/small-garden/">\n\t\t<link rel="icon" href="index.icon.png">');
writeFileSync(htmlPath, html);
writeFileSync(join(destination, '.nojekyll'), '');
console.log(`GitHub Pages 파일 ${files.length}개를 docs/에 준비했습니다.`);
