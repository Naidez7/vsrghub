// VSRG Hub's rankings on the web: read straight from the server (everything here is public).
const HUB = {
	url: "https://ekojitajoifsjdrrjzsv.supabase.co",
	key: "sb_publishable_yDIFMoghR6MJl7IRlkq6bw_xHHrbpH9",
	SKILLS: [["stream", "Stream"], ["jumpstream", "Jumpstream"], ["handstream", "Handstream"], ["stamina", "Stamina"], ["jackspeed", "Jackspeed"], ["chordjack", "Chordjack"], ["technical", "Technical"]],
	// (Etterna's calculator doesn't rate Technical for 7K)
	skillsFor(k) { return k === 7 ? this.SKILLS.filter(([id]) => id !== "technical") : this.SKILLS; },
	async rpc(fn, args) {
		const r = await fetch(`${this.url}/rest/v1/rpc/${fn}`, { method: "POST", headers: { apikey: this.key, "Content-Type": "application/json" }, body: JSON.stringify(args || {}) });
		if (!r.ok) throw new Error((await r.json().catch(() => ({}))).message || r.statusText);
		return r.json();
	},
	async get(path) {
		const r = await fetch(`${this.url}/rest/v1/${path}`, { headers: { apikey: this.key } });
		if (!r.ok) throw new Error((await r.json().catch(() => ({}))).message || r.statusText);
		return r.json();
	},
	picture(id, v, ext) { return v > 0 ? `${this.url}/storage/v1/object/public/avatars/${id}.${ext === "gif" ? "gif" : "png"}?v=${v}` : ""; },
	esc(s) { return String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); },
	avatar(pic, name, cls) { return `<span class="av ${cls || ""}">${pic ? `<img src="${this.esc(pic)}" alt="">` : this.esc(((name || "?")[0] || "?").toUpperCase())}</span>`; },
	dot(s) { const k = ["osu", "lazer", "quaver"].includes(s) ? s : "etterna"; return `<span class="src ${k}" title="${k}"></span>`; },
	date(s) { if (!s) return ""; const d = new Date(s); return isNaN(d) ? "" : d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" }); },
	ago(s) { const d = new Date(s); if (isNaN(d)) return ""; const m = Math.round((Date.now() - d) / 60000); if (m < 1) return "just now"; if (m < 60) return m + " min ago"; const h = Math.round(m / 60); if (h < 24) return h + " h ago"; const days = Math.round(h / 24); return days < 30 ? days + " d ago" : this.date(s); },
	rate(r) { return (+r).toFixed(2).replace(/0$/, "") + "x"; },
	async profile(id) {
		const [ps, ratings, top4, top7, recent, pinned] = await Promise.all([
			this.get(`profiles?select=id,username,created_at,banned,avatar,avatar_ext&id=eq.${encodeURIComponent(id)}`),
			this.get(`player_ratings?select=*&user_id=eq.${encodeURIComponent(id)}`),
			this.rpc("top_scores", { player: id, k: 4, max_rows: 25 }),
			this.rpc("top_scores", { player: id, k: 7, max_rows: 25 }),
			this.get(`scores?select=id,source,chart_key,keys,rate,wife,ssr_overall,msd,song_title,song_artist,chart_name,marvelous,perfect,great,good,bad,miss,max_combo,played_at,submitted_at&valid=eq.true&order=submitted_at.desc&limit=15&user_id=eq.${encodeURIComponent(id)}`),
			this.rpc("pinned_scores", { player: id }).catch(() => []),
		]);
		if (!ps.length) throw new Error("that player isn't there");
		const p = ps[0];
		p.picture = this.picture(p.id, p.avatar, p.avatar_ext);
		p.ratings = ratings; p.top4 = top4; p.top7 = top7; p.recent = recent; p.pinned = pinned;
		p.place = {};
		for (const r of ratings) {
			if (!r.plays) continue;
			p.place[r.keys] = await this.rpc("player_place", { player: id, k: r.keys }).catch(() => 0);
		}
		return p;
	},
	// a play as a row
	play(s, opts) {
		opts = opts || {};
		const link = s.chart_key ? `chart.html?key=${encodeURIComponent(s.chart_key)}&title=${encodeURIComponent((s.song_title || "?") + (s.chart_name ? " · " + s.chart_name : "") + " · " + s.keys + "K")}` : "#";
		return `<a class="play" href="${link}">
			<span class="t">${this.dot(s.source)}${opts.who ? `<b>${this.esc(opts.who)}</b> ` : ""}${this.esc(s.song_title || "?")} <small>${this.esc(s.song_artist || "")}${s.chart_name ? " · " + this.esc(s.chart_name) : ""} · ${s.keys}K</small></span>
			<span class="s">${(+s.ssr_overall).toFixed(2)}</span>
			<span class="d">${this.rate(s.rate)}${s.msd ? ` · MSD ${(+s.msd).toFixed(2)}` : ""} · ${s.marvelous}/${s.perfect}/${s.great}/${s.good}/${s.bad}/${s.miss} · ${s.max_combo}x${opts.when ? " · " + this.date(s.played_at || s.submitted_at) : ""}</span>
			<span class="a">${(+s.wife).toFixed(2)}%</span></a>`;
	},
	ratingBox(r, k) {
		if (!r || !r.plays) return `<div class="rat"><div class="k">${k}K</div><div class="big">—</div><div class="dim">No ranked plays yet</div></div>`;
		return `<div class="rat"><div class="k">${k}K · ${r.plays} chart${r.plays === 1 ? "" : "s"}</div><div class="big">${(+r.overall).toFixed(2)}</div><div class="ss">${this.skillsFor(k).map(([id, nm]) => `<span>${nm}</span><b>${(+r[id] || 0).toFixed(2)}</b>`).join("")}</div></div>`;
	},
	param(n) { return new URLSearchParams(location.search).get(n) || ""; },
};
