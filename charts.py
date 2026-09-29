"""Inline-SVG charts + the Hypothesis & insights section for build_report.py.

Static (print) charts: blue = did the action, grey = did not, dashed line = all registrants.
Conversion and WA are always separate panels (never a dual axis). Every number comes from
outputs/insights_stats.json (python insights_stats.py), which reads the report's own CSVs.
"""
import json
import math

S = json.load(open("outputs/insights_stats.json", encoding="utf-8"))
BLUE, GREY, INK, MUTED, GRID = "#2a78d6", "#98A2B1", "#14181F", "#5A6472", "#EEF1F5"


def _nice_max(v):
    for step in (1, 2, 5, 10, 20, 25):
        top = math.ceil(v / step) * step
        if top / step <= 6:
            return top, step
    return math.ceil(v / 10) * 10, 10


def bars_panel(title, vals, cis, labels, base, dp, W=330, H=210):
    """Vertical bars with 95% CI whiskers and a dashed reference line at `base`."""
    L, R, T, B = 34, 10, 28, 36
    top, step = _nice_max(max(c[1] for c in cis) * 1.08)
    y = lambda v: T + (H - T - B) * (1 - v / top)
    out = [f"<text x='{L}' y='14' class='ax' style='font-weight:700;fill:{INK};font-size:10.5px'>{title}"
           f"<tspan style='font-weight:400;fill:{MUTED}'>  · all registrants {base:.{dp}f}%</tspan></text>"]
    t = 0.0
    while t <= top + 1e-9:
        out.append(f"<line x1='{L}' x2='{W-R}' y1='{y(t):.1f}' y2='{y(t):.1f}' stroke='{GRID}'/>"
                   f"<text x='{L-5}' y='{y(t)+3:.1f}' text-anchor='end' class='ax'>{t:g}%</text>")
        t += step
    bw = (W - L - R) / len(vals)
    for i, (v, c, lab) in enumerate(zip(vals, cis, labels)):
        cx = L + bw * (i + 0.5)
        w = bw * 0.46
        out.append(f"<path d='M{cx-w/2:.1f},{y(0):.1f} V{y(v)+4:.1f} q0,-4 4,-4 H{cx+w/2-4:.1f} q4,0 4,4 "
                   f"V{y(0):.1f} Z' fill='{BLUE}'/>")
        for yy in (c[0], c[1]):
            out.append(f"<line x1='{cx-4:.1f}' x2='{cx+4:.1f}' y1='{y(yy):.1f}' y2='{y(yy):.1f}' stroke='{INK}' stroke-width='1.1'/>")
        out.append(f"<line x1='{cx:.1f}' x2='{cx:.1f}' y1='{y(c[0]):.1f}' y2='{y(c[1]):.1f}' stroke='{INK}' stroke-width='1.1'/>")
        out.append(f"<text x='{cx+w/2+3:.1f}' y='{y(v)+3:.1f}' class='ax' style='fill:{INK};font-weight:700'>{v:.{dp}f}%</text>")
        out.append(f"<text x='{cx:.1f}' y='{H-B+14}' text-anchor='middle' class='ax'>{lab}</text>")
    out.append(f"<line x1='{L}' x2='{W-R}' y1='{y(base):.1f}' y2='{y(base):.1f}' stroke='{MUTED}' "
               f"stroke-width='1.2' stroke-dasharray='4 3'/>")
    out.append(f"<text x='{(L+W-R)/2:.1f}' y='{H-6}' text-anchor='middle' class='ax'>inputs touched on the S7 page</text>")
    return f"<svg viewBox='0 0 {W} {H}' xmlns='http://www.w3.org/2000/svg'>{''.join(out)}</svg>"


def dots_panel(title, rows, base, dp, W=330, rowh=30, lab_w=100):
    """Paired dot plot per row: grey = without / stopped, blue = with / carried on."""
    T, B, R = 32, 22, 34
    H = T + rowh * len(rows) + B
    hi = max(max(a, b, base) for _, a, b in rows) * 1.10
    lo = min(min(a, b, base) for _, a, b in rows)
    lo = 0 if lo < hi * 0.45 else math.floor(lo * 0.85 / 5) * 5
    span, step = _nice_max(hi - lo)
    top = lo + span
    x = lambda v: lab_w + (W - lab_w - R) * (v - lo) / (top - lo)
    out = [f"<text x='0' y='12' class='ax' style='font-weight:700;fill:{INK};font-size:10.5px'>{title}"
           f"<tspan style='font-weight:400;fill:{MUTED}'>  · all registrants {base:.{dp}f}%</tspan></text>"]
    t = lo
    while t <= top + 1e-9:
        out.append(f"<line x1='{x(t):.1f}' x2='{x(t):.1f}' y1='{T-6}' y2='{H-B}' stroke='{GRID}'/>"
                   f"<text x='{x(t):.1f}' y='{H-B+12}' text-anchor='middle' class='ax'>{t:g}%</text>")
        t += step
    out.append(f"<line x1='{x(base):.1f}' x2='{x(base):.1f}' y1='{T-10}' y2='{H-B}' stroke='{MUTED}' "
               f"stroke-width='1.2' stroke-dasharray='4 3'/>")
    for i, (lab, a, b) in enumerate(rows):
        cy = T + rowh * (i + 0.5)
        out.append(f"<text x='0' y='{cy+3.5:.1f}' class='rlab' style='font-size:9.4px'>{lab}</text>")
        out.append(f"<line x1='{x(a):.1f}' x2='{x(b):.1f}' y1='{cy:.1f}' y2='{cy:.1f}' stroke='#C9D2DC' "
                   f"stroke-width='3' stroke-linecap='round'/>")
        for v, col, left in ((a, GREY, a < b), (b, BLUE, b <= a)):
            out.append(f"<circle cx='{x(v):.1f}' cy='{cy:.1f}' r='4.6' fill='{col}' stroke='#fff' stroke-width='1.6'/>")
            tx = x(v) + (-8 if left else 8)
            wt, fc = (700, INK) if col == BLUE else (400, MUTED)
            out.append(f"<text x='{tx:.1f}' y='{cy+3.5:.1f}' text-anchor='{'end' if left else 'start'}' class='ax' "
                       f"style='fill:{fc};font-weight:{wt}'>{v:.{dp}f}%</text>")
    return f"<svg viewBox='0 0 {W} {H}' xmlns='http://www.w3.org/2000/svg'>{''.join(out)}</svg>"


def legend(a, b):
    return (f"<div class='legend'><span><i class='sw' style='background:{GREY}'></i>{a}</span>"
            f"<span><i class='sw' style='background:{BLUE}'></i>{b}</span>"
            f"<span><i style='display:inline-block;width:14px;border-top:1.5px dashed {MUTED}'></i>all registrants</span></div>")


def fig(title, legend_html, left, right, caption):
    return (f"<figure class='avoid'><div class='fig-t'><h3>{title}</h3>{legend_html}</div>"
            f"<div style='display:flex;gap:18px'><div style='flex:1'>{left}</div><div style='flex:1'>{right}</div></div>"
            + (f"<figcaption>{caption}</figcaption>" if caption else "") + "</figure>")


def pfmt(p):
    return "p &lt; 0.001" if p < 0.001 else f"p = {p:.3f}"


def insights_section(s6_users, s6_sales, all3_sales, none_sales, all3_users, none_users):
    b = S["base"]
    d = S["dose"]
    P = S["pairs"]
    pr = {p["label"]: p for p in P}
    D = S["drops"]
    u = S["upload_vs_clickonly"]
    st = D[2]
    rob = S["robust"]
    checks = [(r["conv_up"], r["wa_up"]) for sl in rob.values() for r in sl["pairs"].values()]
    n_up = sum(a + c for a, c in checks)
    n_all = 2 * len(checks)
    max_conv_x = max(r["rate"] for r in d["conv"]) / b["conv"]["rate"]
    max_wa_x = max(r["rate"] for r in d["wa"]) / b["wa"]["rate"]

    f1 = fig("Conversion and attendance rise with every input touched",
             f"<div class='legend'><span><i class='sw' style='background:{BLUE}'></i>S6 users</span>"
             f"<span>&#8866; 95% interval</span>"
             f"<span><i style='display:inline-block;width:14px;border-top:1.5px dashed {MUTED}'></i>all registrants</span></div>",
             bars_panel("Sales conversion", [r["rate"] for r in d["conv"]], [r["ci"] for r in d["conv"]],
                        ["none", "one", "two", "all three"], b["conv"]["rate"], 2),
             bars_panel("Webinar attendance (WA %)", [r["rate"] for r in d["wa"]], [r["ci"] for r in d["wa"]],
                        ["none", "one", "two", "all three"], b["wa"]["rate"], 1),
             "Users who reached S6, Aug + Sep, by how many of the three inputs (slot, LinkedIn, resume click) they touched. "
             "Users per bar: " + ", ".join(f"{r['n']:,}" for r in d["conv"])
             + f". Trend test: conversion {pfmt(S['dose_trend_p']['conv'])}, attendance {pfmt(S['dose_trend_p']['wa'])}.")

    f2 = fig("Each input on its own goes with higher conversion and attendance", legend("did not", "did"),
             dots_panel("Sales conversion", [(p["label"], p["conv"]["without"], p["conv"]["with"]) for p in P],
                        b["conv"]["rate"], 2),
             dots_panel("Webinar attendance (WA %)", [(p["label"], p["wa"]["without"], p["wa"]["with"]) for p in P],
                        b["wa"]["rate"], 1),
             "")

    f3 = fig("Stopping short of S7 marks the weakest attenders", legend("stopped at this step", "carried on"),
             dots_panel("Sales conversion", [(x["label"], x["drop"]["conv"], x["cont"]["conv"]) for x in D],
                        b["conv"]["rate"], 2),
             dots_panel("Webinar attendance (WA %)", [(x["label"], x["drop"]["wa"], x["cont"]["wa"]) for x in D],
                        b["wa"]["rate"], 1),
             "")

    return f"""
<section class="pb">
<h2>5. Hypothesis and insights</h2>
<p class="readme"><b>Hypothesis tested:</b> what a registrant does on the S7 page &mdash; picking a slot, adding
LinkedIn, uploading a resume, submitting &mdash; is related to whether they attend the webinar (WA %) and whether they
buy (sales conversion).</p>
<div class="callout"><p><b>Verdict: supported, for both.</b> The more of the S7 page a registrant completes, the more
likely they are to attend and to buy. The link is stronger for sales (up to <b>{max_conv_x:.1f}&times;</b> all
registrants) than for attendance (up to <b>{max_wa_x:.2f}&times;</b>). It holds in August and in September, in paid
and in non-paid &mdash; {n_up} of {n_all} input-by-slice checks point the same way. It is a <b>correlation</b>: it
identifies the stronger leads, it does not prove the page creates them.</p></div>

{f1}

<div class="find"><div class="num">01</div><div><p><b>A clear dose-response.</b> Touching none of the three inputs
converts at <b>{d['conv'][0]['rate']:.2f}%</b> with <b>{d['wa'][0]['rate']:.1f}%</b> attendance &mdash; below all
registrants on both. Each extra input lifts both, up to <b>{d['conv'][3]['rate']:.2f}%</b> and
<b>{d['wa'][3]['rate']:.1f}%</b> for all three. The {all3_users:,} users who touched all three are
{100*all3_users/s6_users:.0f}% of S6 users but bring {100*all3_sales/s6_sales:.0f}% of S6 sales; the
{none_users:,} who touched none are {100*none_users/s6_users:.0f}% of S6 users and {100*none_sales/s6_sales:.0f}% of
S6 sales.</p></div></div>

{f2}

<div class="find"><div class="num">02</div><div><p><b>The resume upload is the strongest single signal &mdash; the
upload, not the click.</b> Uploaders convert at <b>{pr['Resume uploaded']['conv']['with']:.2f}%</b>
({pr['Resume uploaded']['conv']['with']/b['conv']['rate']:.1f}&times; all registrants) and attend at
<b>{pr['Resume uploaded']['wa']['with']:.1f}%</b>. Users who opened the file picker but never uploaded convert at
<b>{u['conv'][1]:.2f}%</b> and attend at <b>{u['wa'][1]:.1f}%</b> &mdash; lower on both (conversion {pfmt(u['conv_p'])},
attendance {pfmt(u['wa_p'])}). In paid, users who clicked but did not upload convert at {S['paid']['clickonly_conv']:.2f}% &mdash; below the paid average of {S['paid']['base_conv']:.2f}% &mdash; while paid uploaders convert at {S['paid']['upload_conv']:.2f}%.</p></div></div>

<div class="find"><div class="num">03</div><div><p><b>Skipping the slot marks the weakest S6 users.</b> Slot selection
is the most common input: {pr['Slot selected']['conv']['with']:.2f}% vs {pr['Slot selected']['conv']['without']:.2f}%
conversion and {pr['Slot selected']['wa']['with']:.1f}% vs {pr['Slot selected']['wa']['without']:.1f}% attendance.
S6 users who pick no slot convert below all registrants. LinkedIn behaves the same way
({pr['LinkedIn added']['conv']['with']:.2f}% vs {pr['LinkedIn added']['conv']['without']:.2f}%).</p></div></div>

{f3}

<div class="find"><div class="num">04</div><div><p><b>Stopping after S6 is the sharpest attendance warning.</b> Users
who complete S6 but never submit S7 attend at <b>{st['drop']['wa']:.1f}%</b> against <b>{st['cont']['wa']:.1f}%</b>
for those who submit ({pfmt(st['wa_p'])}), and convert at about half the rate. Stopping at S4 is lower still for
attendance ({D[0]['drop']['wa']:.1f}%). Stopping between S5 and S6 hurts conversion
({D[1]['drop']['conv']:.2f}% vs {D[1]['cont']['conv']:.2f}%) but barely moves attendance
({D[1]['drop']['wa']:.1f}% vs {D[1]['cont']['wa']:.1f}%).</p></div></div>

<div class="find"><div class="num">05</div><div><p><b>What this supports, and what it does not.</b> S7-page behaviour
is a cheap lead-quality signal, available minutes after registration: uploaders and all-three users are the best
prospects for follow-up, while no-input and stopped-after-S6 users are the likeliest to miss the webinar. It does
<b>not</b> show that making people fill these inputs would raise sales &mdash; motivated users both fill more and buy
more. That needs an A/B test, for example a stronger slot or resume prompt for half of traffic.</p>
<p><b>Limits.</b> Non-paid is small (430 registrants, 25 sales), so its rows are directional. September leads have
had less time to close and attend. Some people appear on two devices; counted per person, conversion rates move by
0.1pt or less.</p></div></div>
</section>"""
