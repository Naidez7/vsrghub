// The big rating-over-time chart (the launcher's): HUBCHART.open(player, k, points), where each point
// is { day, rating, n, plays: [{ chart_key, song_title, chart_name, rate, ssr_overall, wife, source }] }.
(function () {
const style = document.createElement("style"); style.textContent = `.veil { position: fixed; inset: 0; z-index: 10; background: rgba(7,5,12,.72); backdrop-filter: blur(6px); display: none; place-items: center; }
.veil.show { display: grid; }
.hcard { width: 94vw; height: 86vh; display: flex; flex-direction: column; border-radius: 20px; background: #141020; border: 1px solid var(--edge); box-shadow: 0 30px 90px rgba(0,0,0,.6); padding: 22px 26px 18px; }
.hcard .ph { display: flex; align-items: center; gap: 14px; margin-bottom: 10px; }
.hcard .ph b { font-size: 20px; display: block; } .hcard .ph small { color: var(--dim2); font-size: 12.5px; }
.hcard .ph .x { margin-left: auto; width: 34px; height: 34px; border-radius: 10px; color: var(--dim); font-size: 20px; background: none; border: 0; cursor: pointer; } .hcard .ph .x:hover { background: rgba(255,255,255,.06); color: var(--text); }
.hwrap { position: relative; flex: 1; min-height: 0; border-radius: 14px; background: rgba(0,0,0,.25); border: 1px solid var(--edge); overflow: hidden; }
.hwrap canvas { position: absolute; inset: 0; width: 100%; height: 100%; cursor: crosshair; }
.htip { position: absolute; display: none; min-width: 240px; max-width: 360px; padding: 10px 12px; border-radius: 12px; background: #1c1730; border: 1px solid var(--edge); box-shadow: 0 12px 40px rgba(0,0,0,.5); font-size: 12.5px; pointer-events: none; z-index: 2; }
.htip.pinned { pointer-events: auto; border-color: rgba(255,92,158,.5); }
.htip .hd { display: flex; justify-content: space-between; gap: 12px; font-weight: 700; margin-bottom: 4px; } .htip .hd span { color: var(--pink); }
.htip .n { color: var(--dim2); font-size: 11.5px; margin-bottom: 6px; }
.htip .hp { display: grid; grid-template-columns: 1fr auto; gap: 1px 10px; padding: 5px 0; border-top: 1px solid var(--edge); cursor: pointer; }
.htip .hp:hover { color: var(--pink); }
.htip .hp .t { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; } .htip .hp small { color: var(--dim); }
.htip .hp .r { font-weight: 700; text-align: right; }
.hist .k { display: flex; align-items: center; } .hist .k .hexp { margin-left: auto; width: 22px; height: 22px; border-radius: 7px; color: var(--dim); font-size: 14px; background: none; border: 0; cursor: pointer; } .hist .k .hexp:hover { background: rgba(255,255,255,.08); color: var(--text); }
`; document.head.appendChild(style);
const veil = document.createElement("div"); veil.className = "veil"; veil.id = "hveil";
veil.innerHTML = `<div class="hcard"><div class="ph"><div><b id="h-title"></b><small>Scroll to zoom, drag to pan, double-click to reset. Hover a day for its best plays; click it to keep them open.</small></div><button class="x" id="h-x">✕</button></div><div class="hwrap"><canvas id="hcanvas"></canvas><div class="htip" id="htip"></div></div></div>`;
document.body.appendChild(veil);
let hv = null;
function openHistory(player, k, pts) {
	if (pts.length < 2) return;
	hv = { player, k, pts, t: pts.map(p => new Date(p.day + "T12:00:00").getTime()), hover: -1, pinned: -1 };
	hv.lo = hv.t[0] - 86400e3 * 0.5; hv.hi = hv.t[hv.t.length - 1] + 86400e3 * 0.5; hv.x0 = hv.lo; hv.x1 = hv.hi;
	document.getElementById("h-title").textContent = `${player.username} · ${k}K rating over time`;
	document.getElementById("hveil").classList.add("show");
	drawHistory();
}
function closeHistory() { document.getElementById("hveil").classList.remove("show"); hv = null; }
document.getElementById("h-x").onclick = closeHistory;
document.getElementById("hveil").onclick = e => { if (e.target === document.getElementById("hveil")) closeHistory(); };
document.addEventListener("keydown", e => { if (e.key === "Escape" && hv) closeHistory(); });
addEventListener("resize", () => { if (hv) drawHistory(); });
function histGeom() {
	const cv = document.getElementById("hcanvas"), r = cv.getBoundingClientRect(), D = devicePixelRatio || 1;
	if (cv.width !== Math.round(r.width * D) || cv.height !== Math.round(r.height * D)) { cv.width = Math.round(r.width * D); cv.height = Math.round(r.height * D); }
	const L = 56, R = 18, T = 18, B = 36;
	return { cv, r, D, L, R, T, B, W: r.width, H: r.height, px: t => L + (r.width - L - R) * (t - hv.x0) / (hv.x1 - hv.x0) };
}
function drawHistory() {
	if (!hv) return;
	const g = histGeom(), cx = g.cv.getContext("2d"), { L, R, T, B, W, H, D } = g;
	cx.setTransform(D, 0, 0, D, 0, 0); cx.clearRect(0, 0, W, H);
	// the ratings in view (with a little room)
	const vis = hv.pts.filter((p, i) => hv.t[i] >= hv.x0 && hv.t[i] <= hv.x1);
	const rs = (vis.length ? vis : hv.pts).map(p => p.rating);
	let lo = Math.min(...rs), hi = Math.max(...rs); if (hi - lo < 0.5) { lo -= 0.25; hi += 0.25; } const pad = (hi - lo) * 0.12; lo -= pad; hi += pad;
	const py = v => T + (H - T - B) * (1 - (v - lo) / (hi - lo));
	// grid and the rating axis
	cx.font = "11px Segoe UI, sans-serif"; cx.textBaseline = "middle";
	const ystep = [0.1, 0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10].find(s => (hi - lo) / s <= 8) || 10;
	for (let v = Math.ceil(lo / ystep) * ystep; v <= hi; v += ystep) {
		const y = py(v); cx.strokeStyle = "rgba(255,255,255,.07)"; cx.beginPath(); cx.moveTo(L, y); cx.lineTo(W - R, y); cx.stroke();
		cx.fillStyle = "#8f86a8"; cx.textAlign = "right"; cx.fillText(v.toFixed(ystep < 1 ? 2 : 0), L - 8, y);
	}
	cx.save(); cx.translate(14, (T + H - B) / 2); cx.rotate(-Math.PI / 2); cx.textAlign = "center"; cx.fillStyle = "#6f6886"; cx.font = "bold 10px Segoe UI, sans-serif"; cx.fillText("RATING (MSD)", 0, 0); cx.restore();
	// the date axis: a tick every day, week, month or year as the span allows
	const span = (hv.x1 - hv.x0) / 86400e3, day = 86400e3;
	const ticks = [];
	const add = (t, label) => { const x = g.px(t); if (x >= L && x <= W - R) ticks.push({ x, label }); };
	if (span <= 20) { for (let t = Math.ceil(hv.x0 / day) * day; t <= hv.x1; t += day) { const d = new Date(t); add(t + 12 * 3600e3 - d.getTimezoneOffset() * 60e3 * 0, d.toLocaleDateString(undefined, { month: "short", day: "numeric" })); } }
	else if (span <= 120) { const d = new Date(hv.x0); d.setHours(12, 0, 0, 0); while (d.getDay() !== 1) d.setDate(d.getDate() + 1); for (; d.getTime() <= hv.x1; d.setDate(d.getDate() + 7)) add(d.getTime(), d.toLocaleDateString(undefined, { month: "short", day: "numeric" })); }
	else if (span <= 900) { const d = new Date(hv.x0); d.setDate(1); d.setHours(12, 0, 0, 0); if (d.getTime() < hv.x0) d.setMonth(d.getMonth() + 1); for (; d.getTime() <= hv.x1; d.setMonth(d.getMonth() + 1)) add(d.getTime(), d.toLocaleDateString(undefined, { month: "short", year: span > 400 ? "2-digit" : undefined })); }
	else { const d = new Date(hv.x0); d.setMonth(0, 1); d.setHours(12, 0, 0, 0); if (d.getTime() < hv.x0) d.setFullYear(d.getFullYear() + 1); for (; d.getTime() <= hv.x1; d.setFullYear(d.getFullYear() + 1)) add(d.getTime(), String(d.getFullYear())); }
	cx.textAlign = "center"; cx.textBaseline = "top";
	let lastX = -1e9;
	for (const t of ticks) {
		cx.strokeStyle = "rgba(255,255,255,.05)"; cx.beginPath(); cx.moveTo(t.x, T); cx.lineTo(t.x, H - B); cx.stroke();
		if (t.x - lastX > 54) { cx.fillStyle = "#8f86a8"; cx.font = "11px Segoe UI, sans-serif"; cx.fillText(t.label, t.x, H - B + 8); lastX = t.x; }
	}
	// the line, its shade and the points
	const X = hv.t.map(g.px), Y = hv.pts.map(p => py(p.rating));
	cx.save(); cx.beginPath(); cx.rect(L, T, W - L - R, H - T - B); cx.clip();
	const grad = cx.createLinearGradient(0, T, 0, H - B); grad.addColorStop(0, "rgba(255,92,158,.3)"); grad.addColorStop(1, "rgba(255,92,158,0)");
	cx.beginPath(); X.forEach((x, i) => i ? cx.lineTo(x, Y[i]) : cx.moveTo(x, Y[i])); cx.lineTo(X[X.length - 1], H - B); cx.lineTo(X[0], H - B); cx.closePath(); cx.fillStyle = grad; cx.fill();
	cx.beginPath(); X.forEach((x, i) => i ? cx.lineTo(x, Y[i]) : cx.moveTo(x, Y[i])); cx.strokeStyle = "#ff5c9e"; cx.lineWidth = 2.2; cx.lineJoin = "round"; cx.stroke();
	const dense = (W - L - R) / Math.max(1, vis.length) < 7;
	X.forEach((x, i) => { if (x < L - 5 || x > W - R + 5) return; const on = i === hv.hover || i === hv.pinned; if (dense && !on) return; cx.beginPath(); cx.arc(x, Y[i], on ? 5 : 3, 0, Math.PI * 2); cx.fillStyle = on ? "#ff5c9e" : "#fff"; cx.fill(); if (on) { cx.strokeStyle = "#fff"; cx.lineWidth = 2; cx.stroke(); } });
	const sel = hv.pinned >= 0 ? hv.pinned : hv.hover;
	if (sel >= 0) { cx.strokeStyle = "rgba(255,255,255,.35)"; cx.lineWidth = 1; cx.setLineDash([4, 4]); cx.beginPath(); cx.moveTo(X[sel], T); cx.lineTo(X[sel], H - B); cx.stroke(); cx.setLineDash([]); }
	cx.restore();
	// the day's card
	const tip = document.getElementById("htip");
	if (sel >= 0) {
		const p = hv.pts[sel];
		tip.innerHTML = `<div class="hd">${HUB.esc(HUB.date(p.day))}<span>${p.rating.toFixed(2)}</span></div><div class="n">${p.n || 0} play${p.n === 1 ? "" : "s"} that day${(p.plays || []).length ? " · the best:" : ""}</div>` +
			(p.plays || []).map(q => `<div class="hp" data-ck="${HUB.esc(q.chart_key)}" data-title="${HUB.esc((q.song_title || "?") + (q.chart_name ? " · " + q.chart_name : "") + " · " + hv.k + "K")}"><div class="t">${HUB.dot(q.source)}${HUB.esc(q.song_title || "?")} <small>${HUB.esc(q.chart_name || "")} · ${(+q.rate).toFixed(2).replace(/0$/, "")}x</small></div><div class="r">${(+q.ssr_overall).toFixed(2)}<br><small>${(+q.wife).toFixed(2)}%</small></div></div>`).join("");
		tip.className = "htip" + (hv.pinned >= 0 ? " pinned" : "");
		tip.style.display = "block";
		const tw = tip.offsetWidth, th = tip.offsetHeight;
		let x = X[sel] + 14, y = Y[sel] - th / 2; if (x + tw > W - 6) x = X[sel] - tw - 14; y = Math.max(6, Math.min(H - th - 6, y));
		tip.style.left = x + "px"; tip.style.top = y + "px";
		tip.querySelectorAll("[data-ck]").forEach(r => r.onclick = () => { location.href = "chart.html?key=" + encodeURIComponent(r.dataset.ck) + "&title=" + encodeURIComponent(r.dataset.title); });
	} else tip.style.display = "none";
}
(() => {
	const cv = document.getElementById("hcanvas"); let drag = null;
	const nearest = e => { const g = histGeom(); const mx = e.clientX - g.r.left; let best = -1, bd = 14; hv.t.forEach((t, i) => { const d = Math.abs(g.px(t) - mx); if (d < bd) { bd = d; best = i; } }); return best; };
	cv.onmousemove = e => { if (!hv) return; if (drag) { const g = histGeom(); const dt = (e.clientX - drag.x) * (hv.x1 - hv.x0) / (g.W - g.L - g.R); let x0 = drag.x0 - dt, x1 = drag.x1 - dt; if (x0 < hv.lo) { x1 += hv.lo - x0; x0 = hv.lo; } if (x1 > hv.hi) { x0 -= x1 - hv.hi; x1 = hv.hi; } hv.x0 = x0; hv.x1 = x1; drag.moved = true; drawHistory(); return; } const h = nearest(e); if (h !== hv.hover) { hv.hover = h; drawHistory(); } };
	cv.onmouseleave = () => { if (hv && hv.hover >= 0) { hv.hover = -1; drawHistory(); } };
	cv.onmousedown = e => { if (!hv || e.button !== 0) return; drag = { x: e.clientX, x0: hv.x0, x1: hv.x1, moved: false }; };
	addEventListener("mouseup", e => { if (!hv || !drag) return; const d = drag; drag = null; if (!d.moved) { const h = nearest(e); hv.pinned = hv.pinned === h ? -1 : h; drawHistory(); } });
	cv.onwheel = e => { if (!hv) return; e.preventDefault(); const g = histGeom(); const mx = e.clientX - g.r.left; const f = e.deltaY < 0 ? 1 / 1.25 : 1.25; const at = hv.x0 + (hv.x1 - hv.x0) * (mx - g.L) / (g.W - g.L - g.R); let x0 = at - (at - hv.x0) * f, x1 = at + (hv.x1 - at) * f; const min = 2 * 86400e3; if (x1 - x0 < min) { x0 = at - min / 2; x1 = at + min / 2; } x0 = Math.max(hv.lo, x0); x1 = Math.min(hv.hi, x1); hv.x0 = x0; hv.x1 = x1; drawHistory(); };
	cv.ondblclick = () => { if (!hv) return; hv.x0 = hv.lo; hv.x1 = hv.hi; hv.pinned = -1; drawHistory(); };
})();
window.HUBCHART = { open: (player, k, pts) => openHistory(player, k, pts) };
})();
