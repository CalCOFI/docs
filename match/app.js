// app.js — UI + runtime for CalCOFI Match.
//
// Wires the form to docs/match/match.js (the SQL builders) and to DuckDB-WASM
// (loaded lazily from jsDelivr). The page never talks to any CalCOFI service:
// the only network traffic is the wasm bundle from jsDelivr and Parquet range
// requests to storage.googleapis.com.

import {
  VERSION as MATCH_JS_VERSION,
  matchBioEnv,
  matchIchthyoByName,
  matchIchthyoByTaxon,
  matchZooplanktonBiomass,
  buildBioSQLIchthyo,
  buildEnvSQL,
  extractSourceUrls,
  SQL_HEADER
} from "./match.js";

// Common measurement_types — also queryable from measurement_type.parquet, but
// pre-listed so the form is usable before the wasm bundle finishes loading.
const ENV_VARS = [
  "temperature", "salinity", "oxygen_umol_kg", "phosphate", "silicate",
  "nitrite", "nitrate", "chlorophyll_a", "phaeopigment", "dynamic_height",
  "sigma_theta", "pressure", "par", "ph", "ammonia"
];

// ── tiny DOM helpers ───────────────────────────────────────────────────────
const $  = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

// ── status pill ────────────────────────────────────────────────────────────
const statusEl = $("#status");
let _statusTimer = null;
function setStatus(text, kind = "idle") {
  statusEl.className = kind === "idle" ? "" : kind;
  statusEl.innerHTML = text;
  if (_statusTimer) { clearTimeout(_statusTimer); _statusTimer = null; }
}

// ── form ↔ args ────────────────────────────────────────────────────────────
function readForm(form) {
  const o = {};
  for (const el of form.elements) {
    if (!el.name) continue;
    if (el.type === "checkbox") o[el.name] = el.checked;
    else if (el.type === "radio") { if (el.checked) o[el.name] = el.value; }
    else if (el.type === "number") {
      o[el.name] = el.value === "" ? null : Number(el.value);
    } else {
      o[el.name] = el.value === "" ? null : el.value;
    }
  }
  return o;
}

// ── populate env_var <select>s ─────────────────────────────────────────────
for (const sel of $$("select[data-env-var]")) {
  for (const v of ENV_VARS) {
    const opt = document.createElement("option");
    opt.value = v; opt.textContent = v;
    if (v === "temperature") opt.selected = true;
    sel.appendChild(opt);
  }
}

// ── tabs ───────────────────────────────────────────────────────────────────
$("#tabs").addEventListener("click", (e) => {
  const btn = e.target.closest("button[data-tab]");
  if (!btn) return;
  const tab = btn.dataset.tab;
  for (const b of $$("#tabs button")) b.setAttribute("aria-selected", b === btn);
  for (const f of $$("form.match-form")) f.classList.toggle("hidden", f.dataset.tab !== tab);
});

// ── subtabs (Results / SQL / Metadata) ─────────────────────────────────────
$("#subtabs").addEventListener("click", (e) => {
  const btn = e.target.closest("button[data-subtab]");
  if (!btn) return;
  const sub = btn.dataset.subtab;
  for (const b of $$("#subtabs button")) b.setAttribute("aria-selected", b === btn);
  $("#panel-results").classList.toggle("hidden", sub !== "results");
  $("#panel-sql"    ).classList.toggle("hidden", sub !== "sql");
  $("#panel-meta"   ).classList.toggle("hidden", sub !== "meta");
});

// ── custom-tab pre-fill: the worked-example bio + env CTEs ─────────────────
{
  const version = "v2026.05.14";
  $("#cu-bio").value = buildBioSQLIchthyo({
    version,
    species_where: "sp.scientific_name IN ('Sardinops sagax')",
    life_stage: "larva",
    date_min: "2018-01-01", date_max: "2018-03-31"
  });
  $("#cu-env").value = buildEnvSQL({
    env_var: "temperature", version,
    date_min: "2018-01-01", date_max: "2018-03-31",
    pad_hours: 72
  });
}
$("#sh-example").addEventListener("click", () => {
  $("#sh-sql").value =
`SELECT scientific_name, common_name, worms_id
FROM read_parquet(
  'https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.05.14/parquet/species.parquet')
WHERE common_name ILIKE '%sardine%'
ORDER BY scientific_name;`;
});

// ── DuckDB-WASM (lazy) ─────────────────────────────────────────────────────
const DUCKDB_VERSION = "1.29.0";
let _duckdb = null, _conn = null;

async function getConn() {
  if (_conn) return _conn;
  setStatus("Loading DuckDB-WASM bundle from jsDelivr…", "busy");
  const duckdb = await import(
    `https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@${DUCKDB_VERSION}/+esm`);
  _duckdb = duckdb;
  const bundles = duckdb.getJsDelivrBundles();
  const bundle  = await duckdb.selectBundle(bundles);
  setStatus("Initializing DuckDB-WASM…", "busy");
  const worker = await duckdb.createWorker(bundle.mainWorker);
  const db = new duckdb.AsyncDuckDB(new duckdb.ConsoleLogger(), worker);
  await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
  const conn = await db.connect();
  await conn.query("INSTALL httpfs; LOAD httpfs;");
  await conn.query("INSTALL spatial; LOAD spatial;");
  _conn = conn;
  return conn;
}

// ── arrow-table → JS plain rows ────────────────────────────────────────────
function arrowToRows(arrow) {
  // Use toArray() then JSON-round-trip for stable JS-native values.
  // BigInts → numbers (via replacer) so they render & CSV-serialize cleanly.
  const raw = arrow.toArray().map(r => r.toJSON ? r.toJSON() : r);
  const fields = arrow.schema.fields.map(f => f.name);
  return raw.map(row => {
    const o = {};
    for (const f of fields) {
      let v = row[f];
      if (typeof v === "bigint") v = Number(v);
      else if (v instanceof Date) v = v.toISOString();
      else if (v && typeof v === "object" && v.toString) v = v.toString();
      o[f] = v;
    }
    return o;
  });
}

// ── render results table (paginated, sortable) ─────────────────────────────
const PAGE_SIZE = 100;
const state = { rows: [], cols: [], sortCol: null, sortDir: 1, page: 0 };

function renderTable() {
  const wrap = $("#table-wrap");
  if (!state.rows.length) {
    wrap.innerHTML = `<p style="padding:1rem;color:#5d6d7e">No rows.</p>`;
    $("#pagination").innerHTML = "";
    return;
  }
  const sorted = state.sortCol == null ? state.rows : [...state.rows].sort((a, b) => {
    const av = a[state.sortCol], bv = b[state.sortCol];
    if (av == null && bv == null) return 0;
    if (av == null) return 1;
    if (bv == null) return -1;
    if (av < bv) return -1 * state.sortDir;
    if (av > bv) return  1 * state.sortDir;
    return 0;
  });
  const start = state.page * PAGE_SIZE;
  const page  = sorted.slice(start, start + PAGE_SIZE);

  const isNum = c => page.every(r => r[c] == null || typeof r[c] === "number");

  const html = [
    "<table class='results'><thead><tr>",
    state.cols.map(c => {
      const arrow = state.sortCol === c ? (state.sortDir > 0 ? " ▲" : " ▼") : "";
      return `<th data-col="${c}" class="${isNum(c) ? "num" : ""}" style="cursor:pointer">${c}${arrow}</th>`;
    }).join(""),
    "</tr></thead><tbody>",
    page.map(r => "<tr>" + state.cols.map(c => {
      const v = r[c];
      const cls = typeof v === "number" ? "num" : "";
      const shown = v == null ? "" :
                    typeof v === "number" ? (Number.isInteger(v) ? v : v.toFixed(4)) :
                    String(v);
      return `<td class="${cls}">${escHtml(shown)}</td>`;
    }).join("") + "</tr>").join(""),
    "</tbody></table>"
  ].join("");
  wrap.innerHTML = html;

  const total = sorted.length;
  const pages = Math.ceil(total / PAGE_SIZE);
  $("#pagination").innerHTML = pages <= 1 ? "" : `
    <button id="pg-prev" ${state.page === 0 ? "disabled" : ""}>← prev</button>
    <span>page ${state.page + 1} of ${pages} (rows ${start + 1}–${Math.min(start + PAGE_SIZE, total)} of ${total})</span>
    <button id="pg-next" ${state.page >= pages - 1 ? "disabled" : ""}>next →</button>`;
}
function escHtml(s) { return String(s).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c])); }

$("#table-wrap").addEventListener("click", (e) => {
  const th = e.target.closest("th[data-col]");
  if (!th) return;
  const col = th.dataset.col;
  if (state.sortCol === col) state.sortDir *= -1;
  else { state.sortCol = col; state.sortDir = 1; }
  state.page = 0;
  renderTable();
});
$("#pagination").addEventListener("click", (e) => {
  if (e.target.id === "pg-prev" && state.page > 0)   { state.page--; renderTable(); }
  if (e.target.id === "pg-next") { state.page++; renderTable(); }
});

// ── download CSV / copy + download SQL ─────────────────────────────────────
function rowsToCSV(cols, rows) {
  const esc = v => v == null ? "" :
    /[",\n]/.test(String(v)) ? `"${String(v).replace(/"/g, '""')}"` : String(v);
  return cols.join(",") + "\n" + rows.map(r => cols.map(c => esc(r[c])).join(",")).join("\n") + "\n";
}
function download(name, mime, body) {
  const blob = new Blob([body], { type: mime });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement("a");
  a.href = url; a.download = name; document.body.appendChild(a); a.click();
  setTimeout(() => { document.body.removeChild(a); URL.revokeObjectURL(url); }, 0);
}
$("#dl-csv").addEventListener("click", () =>
  download(`calcofi_match_${Date.now()}.csv`, "text/csv", rowsToCSV(state.cols, state.rows)));
$("#dl-sql").addEventListener("click", () => {
  const sql = $("#sql-text").textContent;
  download(`calcofi_match_${Date.now()}.sql`, "text/plain", SQL_HEADER + sql + "\n");
});
$("#copy-sql").addEventListener("click", async () => {
  await navigator.clipboard.writeText(SQL_HEADER + $("#sql-text").textContent + "\n");
  const btn = $("#copy-sql"), prev = btn.textContent;
  btn.textContent = "✓ copied"; setTimeout(() => { btn.textContent = prev; }, 1200);
});

// ── run! ───────────────────────────────────────────────────────────────────
async function run(form) {
  const tab = form.dataset.tab;
  const args = readForm(form);
  const submitBtn = $("button[type=submit]", form);
  submitBtn.disabled = true;

  let sql, queryMeta;
  try {
    if (tab === "by-name") {
      ({ sql, queryMeta } = matchIchthyoByName(args));
    } else if (tab === "by-taxon") {
      ({ sql, queryMeta } = matchIchthyoByTaxon(args));
    } else if (tab === "zoo") {
      ({ sql, queryMeta } = matchZooplanktonBiomass(args));
    } else if (tab === "custom") {
      ({ sql, queryMeta } = matchBioEnv(args));
    } else if (tab === "shell") {
      sql = args.sql;
      queryMeta = {
        match_js_version: MATCH_JS_VERSION,
        release_version:  args.version || null,
        params:           { mode: "shell" },
        source_urls:      extractSourceUrls(sql),
        generated_at:     new Date().toISOString().replace("T", " ").replace(/\.\d+Z$/, " UTC")
      };
    }
  } catch (err) {
    setStatus(`✗ SQL build failed: ${escHtml(err.message)}`, "error");
    submitBtn.disabled = false;
    return;
  }

  const conn = await getConn().catch(err => {
    setStatus(`✗ DuckDB-WASM init failed: ${escHtml(err.message)}`, "error");
    submitBtn.disabled = false;
    return null;
  });
  if (!conn) return;

  const t0 = performance.now();
  setStatus(`Running query against <code>${escHtml(queryMeta.source_urls?.[0]?.split('/').slice(0,7).join('/') || 'GCS')}</code>…`, "busy");
  try {
    const arrow = await conn.query(sql);
    const rows  = arrowToRows(arrow);
    const cols  = arrow.schema.fields.map(f => f.name);
    const sec   = ((performance.now() - t0) / 1000).toFixed(1);

    state.rows = rows; state.cols = cols; state.page = 0;
    state.sortCol = null; state.sortDir = 1;

    if (tab !== "shell") queryMeta.n_rows = rows.length;

    $("#output").classList.remove("hidden");
    $("#row-count").innerHTML = `<strong>${rows.length}</strong> row${rows.length === 1 ? "" : "s"} · ${cols.length} cols · ${sec}s`;
    $("#sql-text").textContent = sql;
    $("#meta-text").textContent = JSON.stringify(queryMeta, null, 2);
    renderTable();

    setStatus(`✓ Done: ${rows.length} row${rows.length === 1 ? "" : "s"} in ${sec}s`, "success");
  } catch (err) {
    setStatus(`✗ Query failed: ${escHtml(err.message)}`, "error");
    // still show the SQL so the user can see what was attempted
    $("#output").classList.remove("hidden");
    $("#sql-text").textContent = sql;
    $("#meta-text").textContent = JSON.stringify(queryMeta, null, 2);
    // switch to SQL panel so user sees the query
    $$("#subtabs button").forEach(b => b.setAttribute("aria-selected", b.dataset.subtab === "sql"));
    $("#panel-results").classList.add("hidden");
    $("#panel-sql").classList.remove("hidden");
    $("#panel-meta").classList.add("hidden");
  } finally {
    submitBtn.disabled = false;
  }
}

for (const form of $$("form.match-form")) {
  form.addEventListener("submit", (e) => { e.preventDefault(); run(form); });
}

// ── deep link: ?version=vYYYY.MM.DD overrides every version input ──────────
{
  const u = new URL(location.href);
  const v = u.searchParams.get("version");
  if (v && /^v\d{4}\.\d{2}/.test(v)) {
    for (const el of $$("input[data-version]")) el.value = v;
  }
}
