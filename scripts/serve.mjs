import { createServer as createHttpServer } from "node:http";
import { createServer as createHttpsServer } from "node:https";
import { createReadStream, readFileSync, statSync } from "node:fs";
import { isIP } from "node:net";
import { resolve, sep } from "node:path";

const root = resolve(process.argv[2] ?? "build/web");
const port = Number(process.argv[3] ?? 8765);
const host = process.argv[4] ?? "127.0.0.1";
const certPath = process.argv[5];
const keyPath = process.argv[6];
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error("포트는 1~65535 사이의 정수여야 합니다.");
}
if (host !== "127.0.0.1" && isIP(host) !== 4) {
  throw new Error("호스트는 127.0.0.1 또는 휴대폰과 같은 네트워크의 IPv4 주소여야 합니다.");
}
if (Boolean(certPath) !== Boolean(keyPath)) {
  throw new Error("HTTPS 인증서와 개인 키 경로를 함께 지정해 주세요.");
}
if (host !== "127.0.0.1" && !certPath) {
  throw new Error("휴대폰 접속에는 HTTPS가 필요합니다. scripts/serve-phone.ps1을 사용해 주세요.");
}
const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
  ".json": "application/json",
};

const handleRequest = (request, response) => {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  } catch {
    response.writeHead(400).end();
    return;
  }
  const file = resolve(root, `.${pathname === "/" ? "/index.html" : pathname}`);
  if (!file.startsWith(root + sep)) {
    response.writeHead(403).end();
    return;
  }
  try {
    const stat = statSync(file);
    if (!stat.isFile()) throw new Error("not a file");
    const extension = file.slice(file.lastIndexOf("."));
    response.writeHead(200, {
      "Content-Type": mime[extension] ?? "application/octet-stream",
      "Content-Length": stat.size,
      "Cache-Control": "no-store",
    });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end();
  }
};

const server = certPath
  ? createHttpsServer({ cert: readFileSync(certPath), key: readFileSync(keyPath) }, handleRequest)
  : createHttpServer(handleRequest);
server.listen(port, host, () => {
  const scheme = certPath ? "https" : "http";
  process.stdout.write(`${host === "127.0.0.1" ? "작은정원" : "휴대폰 주소"}: ${scheme}://${host}:${port}/\n`);
});
