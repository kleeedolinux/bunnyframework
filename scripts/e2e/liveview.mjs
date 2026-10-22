// Browser e2e: drives /counter in a Chromium-based browser over CDP (port 9339).
// Run: brave --headless=new --remote-debugging-port=9339 --user-data-dir=$(mktemp -d) & PORT=4000 node scripts/e2e/liveview.mjs
const list = await (await fetch("http://127.0.0.1:9339/json/list")).json();
const page = list.find(t => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0; const pending = {}; const errors = [];
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending[m.id]) { pending[m.id](m.result); delete pending[m.id]; }
  if (m.method === "Runtime.exceptionThrown") errors.push(m.params.exceptionDetails.text);
  if (m.method === "Runtime.consoleAPICalled" && m.params.type === "error") errors.push(JSON.stringify(m.params.args));
};
await new Promise(r => ws.onopen = r);
const send = (method, params = {}) => new Promise(r => { const i = ++id; pending[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
const evalJs = async (expr) => (await send("Runtime.evaluate", { expression: expr, returnByValue: true })).result.value;
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
await send("Runtime.enable");
await send("Page.enable");
await send("Page.navigate", { url: "http://localhost:" + (process.env.PORT || "4000") + "/counter" });
await sleep(1500);
const h2 = () => evalJs("document.querySelector('[bunny-live] h2').textContent");
console.log("initial:", await h2());
for (let i = 0; i < 3; i++) { await evalJs("document.querySelector('[bunny-click=inc]').click()"); await sleep(300); console.log("after inc:", await h2()); }
await evalJs("document.querySelector('[bunny-click=dec]').click()"); await sleep(300);
console.log("after dec:", await h2());
console.log("errors:", errors.length ? errors : "none");
process.exit(0);
