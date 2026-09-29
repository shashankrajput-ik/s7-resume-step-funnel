"""Build report/S7_Page_Behaviour_Conversion.pdf from outputs/*.csv via headless Chrome.
Run: python verify.py && python build_report.py

House style is borrowed from the page-group report at build time (same as the s2-s3 report), so the
documents cannot drift apart visually. Tables only plus 'How to read this' lines and mechanical
footnotes - no interpretation in the PDF.
"""
import csv, subprocess
from charts import insights_section
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE / "report"; OUT.mkdir(exist_ok=True)
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

_src = (HERE.parent / "page-group-funnel" / "build_report.py").read_text(encoding="utf-8")
_i = _src.index('CSS = """') + len('CSS = """')
CSS = _src[_i:_src.index('"""', _i)]

BASE = "A00 All registrations (reached S4) = overall"
M = ("users", "sales", "attended", "reg_held", "att_held")
PERIODS = {"Aug+Sep": "Aug + Sep", "2026-08": "August", "2026-09": "September *"}


def load(path, key):
    D = {}
    for r in csv.DictReader(open(HERE / "outputs" / path, encoding="utf-8")):
        D[(key(r), r["segment"])] = [int(r[k]) if r[k] else None for k in M]
    return D


O = load("14_conv_wa_unique_users_aug_sep.csv", lambda r: r["period"])
G = load("15_conv_wa_paid_nonpaid_aug_sep.csv", lambda r: (r["period"], r["grp"]))
F = [r for r in csv.DictReader(open(HERE / "outputs" / "03_funnel_mom.csv")) if r["month"] >= "2026-08"]
R16 = {r["k"]: int(r["v"]) for r in csv.DictReader(open(HERE / "outputs" / "16_recon_independent.csv"))}
R17 = {r["grain"]: r for r in csv.DictReader(open(HERE / "outputs" / "17_recon_person_grain.csv"))}


def heat_x(x):
    """Lift vs overall: green above 1.00x, red below; faint near 1."""
    if x is None:
        return ""
    a = min(abs(x - 1.0), 1.0) * 0.32
    if abs(x - 1.0) < 0.05:
        return ""
    col = "18,133,92" if x > 1 else "192,57,43"
    return f' style="background:rgba({col},{a:.3f})"'


def pc(n, d, dp=2):
    return "&mdash;" if not d else f"{100*n/d:.{dp}f}%"


# ---------------------------------------------------------------- 1. funnel
def funnel_table():
    steps = [("s1", "S1 &nbsp;Traffic excl. bounced"),
             ("s2", "S2 &nbsp;CTA &rarr; webinar"), ("s3", "S3 &nbsp;PII submitted"),
             ("s4", "S4 &nbsp;Webinar slots (registration)"), ("s5", "S5 &nbsp;GQL form"),
             ("s6", "S6 &nbsp;Qualifier form"), ("s7", "S7 &nbsp;Resume step / finish")]
    lab = {"2026-08": ("August", "1 &ndash; 31 Aug"), "2026-09": ("September *", "1 &ndash; 28 Sep")}
    h1 = "".join(f"<th class='grpcol gtop gstart' colspan='2'>{lab[r['month']][0]}<br>"
                 f"<span class='sub'>{lab[r['month']][1]}</span></th>" for r in F)
    h2 = "".join("<th class='gstart'>users</th><th>% of S1</th>" for _ in F)
    body = []
    for k, name in steps:
        cls = " class='hl'" if k in ("s4", "s7") else ""
        cells = "".join(f"<td class='gstart'>{int(r[k]):,}</td>"
                        f"<td class='pc'>{'&mdash;' if k in ('s0','s1') else pc(int(r[k]), int(r['s1']))}</td>" for r in F)
        body.append(f"<tr{cls}><td class='step'>{name}</td>{cells}</tr>")
    body.append(f"<tr class='sep'><td class='step' colspan='{1+2*len(F)}'>Step conversion</td></tr>")
    for a, b, name in [("s2", "s1", "S2 &divide; S1"), ("s3", "s2", "S3 &divide; S2"), ("s4", "s3", "S4 &divide; S3"),
                       ("s4", "s1", "S4 &divide; S1"), ("s5", "s4", "S5 &divide; S4"), ("s6", "s5", "S6 &divide; S5"),
                       ("s7", "s6", "S7 &divide; S6"), ("s7", "s1", "S7 &divide; S1"), ("s7", "s4", "S7 &divide; S4")]:
        cls = "derived em-row" if (a, b) in (("s7", "s1"), ("s7", "s4")) else "derived"
        cells = "".join(f"<td class='gstart pc2' colspan='2'>{pc(int(r[a]), int(r[b]))}</td>" for r in F)
        body.append(f"<tr class='{cls}'><td class='step'>{name}</td>{cells}</tr>")
    return (f"<div class='tbl'><table class='ofn'><thead><tr><th class='step' rowspan='2'>Step</th>{h1}</tr>"
            f"<tr class='sub-h'>{h2}</tr></thead><tbody>{''.join(body)}</tbody></table></div>")


# ---------------------------------------------------------------- 2/3. behaviour vs conversion & WA
GROUPS = [("A", None), ("B", "Inputs touched on the S7 page &mdash; slot / LinkedIn / resume click"),
          ("C", "Each input on its own"), ("D", "Drop-off vs completion")]


def behaviour_table(D, key):
    b = D[(key, BASE)]
    s6 = D[(key, "A01 Reached S6")][0]
    bc, bw = b[1] / b[0], b[2] / b[0]
    segs = sorted(s for (k, s) in D if k == key and not s.startswith("Z"))
    body = []
    for letter, title in GROUPS:
        if title:
            body.append(f"<tr class='sep'><td class='step' colspan='12'>{title}</td></tr>")
        for s in [x for x in segs if x[0] == letter]:
            n, sa, at, rh, ah = D[(key, s)]
            name = s[4:].replace("->", "&rarr;").replace("<=", "&le;").replace(" = overall", "")
            ind = s[:3] in ("B03", "B04", "B05")
            if ind:
                name = "&#8627; " + name.replace("one input = ", "")
            share = "" if (s[0] == "D" or s == BASE) else f"{100*n/s6:.1f}%"
            cr, wr = sa / n, at / n
            xc, xw = cr / bc, wr / bw
            cls = " class='hl'" if s in (BASE,) else ""
            pad = " style='padding-left:20px;font-weight:400'" if ind else ""
            body.append(
                f"<tr{cls}><td class='step'{pad}>{name}</td><td>{n:,}</td><td class='pc'>{share}</td>"
                f"<td>{sa:,}</td><td>{100*cr:.2f}%</td><td class='thin'>{100*bc:.2f}%</td>"
                f"<td{heat_x(xc)}>{xc:.2f}x</td><td>{at:,}</td><td>{100*wr:.1f}%</td>"
                f"<td class='thin'>{100*bw:.1f}%</td><td{heat_x(xw)}>{xw:.2f}x</td>"
                f"<td class='pc'>{pc(ah, rh, 1)}</td></tr>")
    head = ("<tr><th class='step' rowspan='2'>Segment</th><th rowspan='2'>Users</th>"
            "<th rowspan='2'>Share<br>of S6</th>"
            "<th class='grpcol gstart' colspan='4'>Conversion</th>"
            "<th class='grpcol gstart' colspan='5'>Webinar attendance</th></tr>"
            "<tr class='sub-h'><th class='gstart'>sales</th><th>conv %</th><th>overall</th><th>&times; overall</th>"
            "<th class='gstart'>attended</th><th>WA %</th><th>overall</th><th>&times; overall</th><th>WA % held</th></tr>")
    return (f"<div class='tbl'><table class='wide bh'><thead>{head}</thead>"
            f"<tbody>{''.join(body)}</tbody></table></div>")


# ---------------------------------------------------------------- appendix: month over month
def mom_table(D, keyf):
    segs = sorted(s for (k, s) in D if k == keyf("Aug+Sep") and not s.startswith("Z"))
    ks = [("2026-08", "August"), ("2026-09", "September *")]
    body = []
    for letter, title in GROUPS:
        if title:
            body.append(f"<tr class='sep'><td class='step' colspan='9'>{title}</td></tr>")
        for s in [x for x in segs if x[0] == letter]:
            name = s[4:].replace("->", "&rarr;").replace("<=", "&le;").replace(" = overall", "")
            ind = s[:3] in ("B03", "B04", "B05")
            if ind:
                name = "&#8627; " + name.replace("one input = ", "")
            pad = " style='padding-left:20px;font-weight:400'" if ind else ""
            cells = []
            for k, _ in ks:
                b = D[(keyf(k), BASE)]; bc, bw = b[1] / b[0], b[2] / b[0]
                n, sa, at, _, _ = D[(keyf(k), s)]
                cells.append(f"<td class='gstart'>{n:,}</td><td>{100*sa/n:.2f}%</td>"
                             f"<td{heat_x(sa/n/bc)}>{sa/n/bc:.2f}x</td><td>{100*at/n:.1f}%</td>")
            cls = " class='hl'" if s == BASE else ""
            body.append(f"<tr{cls}><td class='step'{pad}>{name}</td>{''.join(cells)}</tr>")
    head = ("<tr><th class='step' rowspan='2'>Segment</th>"
            + "".join(f"<th class='grpcol gstart' colspan='4'>{l}</th>" for _, l in ks) + "</tr>"
            "<tr class='sub-h'>" + "<th class='gstart'>users</th><th>conv %</th><th>&times; overall</th><th>WA %</th>" * 2 + "</tr>")
    return f"<div class='tbl'><table class='wide bh'><thead>{head}</thead><tbody>{''.join(body)}</tbody></table></div>"


# ---------------------------------------------------------------- reconciliation
def recon_table():
    o = O[("Aug+Sep", BASE)]; s6 = O[("Aug+Sep", "A01 Reached S6")]
    up = O[("Aug+Sep", "C07 S6 + resume uploaded (<=2h)")]
    pg, ug = R17["person_grain"], R17["uuid_grain"]
    rows = [
        ("S4 users before the lead match = funnel S4", f"Aug {O[('2026-08','Z01 Reached S4, before lead match')][0]:,} / Sep {O[('2026-09','Z01 Reached S4, before lead match')][0]:,}",
         f"Aug {int(F[0]['s4']):,} / Sep {int(F[1]['s4']):,}", "exact"),
        ("S4 users matched to a Bq_data_Alumni lead (table base)", f"{o[0]:,}", f"of {O[('Aug+Sep','Z01 Reached S4, before lead match')][0]:,} unique S4 users",
         f"{100*o[0]/O[('Aug+Sep','Z01 Reached S4, before lead match')][0]:.1f}%"),
        ("Independent recompute &mdash; base users / sales / attended", f"{o[0]:,} / {o[1]} / {o[2]:,}",
         f"{R16['base_S4_users']:,} / {R16['base_sales']} / {R16['base_attended']:,}", "exact"),
        ("Independent recompute &mdash; reached S6 users / sales", f"{s6[0]:,} / {s6[1]}", f"{R16['S6_users']:,} / {R16['S6_sales']}", "exact"),
        ("Independent recompute &mdash; resume uploaded users / sales / attended", f"{up[0]:,} / {up[1]} / {up[2]}",
         f"{R16['S6_uploaded_users']:,} / {R16['S6_uploaded_sales']} / {R16['S6_uploaded_att']}", "exact"),
        ("Upload source: Resume Analysis table vs master_table step-5 (from 4 Aug)", f"{R16['XCHK_uploaded_via_legacy_same_window']:,}",
         f"{R16['XCHK_uploaded_via_master_table']:,}", f"{100*abs(R16['XCHK_uploaded_via_master_table']-R16['XCHK_uploaded_via_legacy_same_window'])/R16['XCHK_uploaded_via_master_table']:.1f}% apart"),
        ("Bq_data_Alumni sale-users (dupe_logic = 1, Aug&ndash;Sep) inside the base", f"{R16['base_sales']}", f"of {R16['SRC_alumni_sale_users']}",
         f"{R16['base_sales']*100/R16['SRC_alumni_sale_users']:.1f}%"),
        ("Person grain (hubspot id) vs user grain &mdash; base conv %", f"{100*int(ug['sales'])/int(ug['base']):.2f}%",
         f"{100*int(pg['sales'])/int(pg['base']):.2f}%", f"{R16['CHK_hsid_with_2plus_uuids_in_base']} ids on 2+ devices"),
        ("Person grain vs user grain &mdash; base WA %", f"{100*int(ug['att'])/int(ug['base']):.1f}%",
         f"{100*int(pg['att'])/int(pg['base']):.1f}%", f"{abs(100*int(ug['att'])/int(ug['base'])-100*int(pg['att'])/int(pg['base'])):.1f}pt"),
    ]
    body = "".join(f"<tr><td class='step' style='font-weight:400;white-space:normal'>{a}</td><td>{b}</td><td>{c}</td><td class='pc'>{d}</td></tr>" for a, b, c, d in rows)
    return ("<div class='tbl'><table class='wide'><thead><tr><th class='step'>Check</th><th>This report</th>"
            f"<th>Independent / source</th><th>Result</th></tr></thead><tbody>{body}</tbody></table></div>")


EXTRA = """<style>
.readme{background:#f7f9fb;border-left:3px solid #9bb0c4;padding:8px 12px;margin:0 0 10px;font-size:9pt;color:#334}
.readme b{color:#112}
.note{font-size:8.6pt;color:#3E4756;margin:6px 0}
header .sub{font-size:7.9pt;line-height:1.55;color:#8A94A3;margin:0 0 8px}
header .sub b{color:#5A6472}
table.bh th,table.bh td{padding:3.6px 4.2px;font-size:7.5pt}
table.bh td.step{font-size:7.9pt}
table.bh th.gstart,table.bh td.gstart{border-left:1px solid #DDE2E9}
table.bh tr.sep td{background:#F4F6F9;border-top:1px solid #DDE2E9;font-family:Consolas,monospace;font-size:6.8pt;
  letter-spacing:.1em;text-transform:uppercase;color:#8A94A3;font-weight:600;padding:4px 7px}
table.ofn tr.sep td{background:#F4F6F9}
table.ofn th,table.ofn td{padding:4.6px 11px}
</style>"""

rp = O[("Aug+Sep", BASE)]
HTML = f"""<!doctype html><html><head><meta charset="utf-8">
<title>S7 Page Behaviour and Conversion</title><style>{CSS}</style>{EXTRA}</head><body>

<header><div class="eyebrow">Webinar funnel &middot; S7 page behaviour &middot; conversion &amp; attendance &middot; US</div>
<h1>What registrants do on the S7 page</h1>
<p class="sub">Every US user who reached <b>S6</b> (qualifier form done) lands on the S7 page: pick a time slot, add a
LinkedIn URL, upload a resume, finish. This report counts who did what there, and how each group converted to a sale
and attended the webinar against all registrants. <b>{rp[0]:,} registrants, 1 August &ndash; 28 September 2026.</b></p>
</header>

<section class="first">
<h2>1. Overall funnel, month over month</h2>
<p class="readme"><b>How to read this:</b> distinct users per step, each step counted independently, so a step is
everyone who reached it that month. Percentages in the step-conversion block divide the two steps named.</p>
{funnel_table()}
<p class="note">* September runs to 28 September.</p>
</section>

<section class="pb">
<h2>2. Month over month &mdash; overall</h2>
<p class="readme"><b>How to read this:</b> section 3 split by month. Each month is compared with its own registrants;
September has had less time to close, so read across rows within a month, not down columns between months.</p>
{mom_table(O, lambda p: p)}
<p class="note">* September runs to 28 September. A user active in both months appears in each, so the months sum to
slightly more than section 3.</p>
</section>

<section class="pb">
<h2>3. S7 page behaviour vs conversion and attendance &mdash; overall</h2>

{behaviour_table(O, 'Aug+Sep')}

</section>

<section class="pb">
<h2>4a. Paid &mdash; LinkedIn, Google NB, Facebook, Google Discovery</h2>

{behaviour_table(G, ('Aug+Sep', 'Paid'))}
</section>

<section class="pb">
<h2>4b. Non-paid &mdash; Organic</h2>

{behaviour_table(G, ('Aug+Sep', 'Non-paid'))}

</section>





{insights_section(O[('Aug+Sep','A01 Reached S6')][0], O[('Aug+Sep','A01 Reached S6')][1], O[('Aug+Sep','B07 S6 + all three inputs')][1], O[('Aug+Sep','B01 S6 + touched no input')][1], O[('Aug+Sep','B07 S6 + all three inputs')][0], O[('Aug+Sep','B01 S6 + touched no input')][0])}

<footer><span>Webinar funnel &middot; S7 page behaviour &middot; US &middot; 1 Aug &ndash; 28 Sep 2026</span>
<span>Generated 29 Sep 2026 &middot; read-only</span></footer>
</body></html>"""

(OUT / "index.html").write_text(HTML, encoding="utf-8")
pdf = OUT / "S7_Page_Behaviour_Conversion.pdf"
subprocess.run([CHROME, "--headless", "--disable-gpu", "--no-pdf-header-footer",
                f"--print-to-pdf={pdf}", (OUT / "index.html").as_uri()], check=True)
print("wrote", pdf)
