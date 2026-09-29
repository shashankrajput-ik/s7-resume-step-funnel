"""Statistics behind the Hypothesis & insights section. Reads the same CSVs as the report."""
import csv, json, math
M = ("users", "sales", "attended", "reg_held", "att_held")
def load(path, key):
    D = {}
    for r in csv.DictReader(open(f"outputs/{path}", encoding="utf-8")):
        D[(key(r), r["segment"][:3])] = [int(r[k]) if r[k] else None for k in M]
    return D
O = load("14_conv_wa_unique_users_aug_sep.csv", lambda r: r["period"])
G = load("15_conv_wa_paid_nonpaid_aug_sep.csv", lambda r: (r["period"], r["grp"]))

def wilson(k, n, z=1.96):
    p = k / n; d = 1 + z*z/n; c = (p + z*z/(2*n)) / d; h = z*math.sqrt(p*(1-p)/n + z*z/(4*n*n)) / d
    return [100*(c-h), 100*(c+h)]
def ztest(k1, n1, k2, n2):
    p = (k1+k2)/(n1+n2); se = math.sqrt(p*(1-p)*(1/n1+1/n2))
    z = (k1/n1 - k2/n2)/se if se else 0
    return 2*(1-0.5*(1+math.erf(abs(z)/math.sqrt(2))))
def trend(ks, ns, scores):
    """Cochran-Armitage test for trend."""
    N = sum(ns); K = sum(ks); p = K/N
    T = sum(s*(k - n*p) for k, n, s in zip(ks, ns, scores))
    V = p*(1-p)*(sum(n*s*s for n, s in zip(ns, scores)) - sum(n*s for n, s in zip(ns, scores))**2/N)
    z = T/math.sqrt(V); return 2*(1-0.5*(1+math.erf(abs(z)/math.sqrt(2))))

def rates(D, k, seg, col):
    n = D[(k, seg)][0]; x = D[(k, seg)][1 if col == "conv" else 2]
    return {"n": n, "k": x, "rate": 100*x/n, "ci": wilson(x, n)}

out = {"base": {c: rates(O, "Aug+Sep", "A00", c) for c in ("conv", "wa")}}
# 1. dose-response
segs = ["B01", "B02", "B06", "B07"]
out["dose"] = {c: [rates(O, "Aug+Sep", s, c) for s in segs] for c in ("conv", "wa")}
out["dose_trend_p"] = {c: trend([O[("Aug+Sep", s)][1 if c == "conv" else 2] for s in segs],
                                [O[("Aug+Sep", s)][0] for s in segs], [0, 1, 2, 3]) for c in ("conv", "wa")}
# 2. with vs without
PAIRS = [("Slot selected", "C01", "C02"), ("LinkedIn added", "C03", "C04"), ("Resume clicked", "C05", "C06"),
         ("Resume uploaded", "C07", "C09"), ("Submitted S7", "D01", "D02")]
def pairs(D, k):
    res = []
    for lab, a, b in PAIRS:
        row = {"label": lab}
        for c, i in (("conv", 1), ("wa", 2)):
            A, B = D[(k, a)], D[(k, b)]
            row[c] = {"with": 100*A[i]/A[0], "without": 100*B[i]/B[0], "p": ztest(A[i], A[0], B[i], B[0]),
                      "with_ci": wilson(A[i], A[0]), "without_ci": wilson(B[i], B[0])}
        res.append(row)
    return res
out["pairs"] = pairs(O, "Aug+Sep")
# upload vs click-only
A, B = O[("Aug+Sep", "C07")], O[("Aug+Sep", "C08")]
out["upload_vs_clickonly"] = {"conv_p": ztest(A[1], A[0], B[1], B[0]), "wa_p": ztest(A[2], A[0], B[2], B[0]),
                              "conv": [100*A[1]/A[0], 100*B[1]/B[0]], "wa": [100*A[2]/A[0], 100*B[2]/B[0]]}
# 3. drop-off
DROPS = [("S4 → S5", "D05", "D06"), ("S5 → S6", "D03", "D04"), ("S6 → S7", "D01", "D02")]
out["drops"] = []
for lab, a, b in DROPS:
    A, B = O[("Aug+Sep", a)], O[("Aug+Sep", b)]
    out["drops"].append({"label": lab, "cont": {"conv": 100*A[1]/A[0], "wa": 100*A[2]/A[0]},
                         "drop": {"conv": 100*B[1]/B[0], "wa": 100*B[2]/B[0], "n": B[0]},
                         "conv_p": ztest(A[1], A[0], B[1], B[0]), "wa_p": ztest(A[2], A[0], B[2], B[0])})
# 4. robustness: does 'with' beat 'without' in each slice?
slices = {"August": (O, "2026-08"), "September": (O, "2026-09"),
          "Paid": (G, ("Aug+Sep", "Paid")), "Non-paid": (G, ("Aug+Sep", "Non-paid"))}
rob = {}
for name, (D, k) in slices.items():
    ps = pairs(D, k)
    all3 = D[(k, "B07")]; none = D[(k, "B01")]
    rob[name] = {"pairs": {p["label"]: {"conv_up": p["conv"]["with"] > p["conv"]["without"], "wa_up": p["wa"]["with"] > p["wa"]["without"],
                                         "conv_p": p["conv"]["p"], "wa_p": p["wa"]["p"]} for p in ps},
                 "all3_vs_none_conv": [100*all3[1]/all3[0], 100*none[1]/none[0], ztest(all3[1], all3[0], none[1], none[0])],
                 "all3_vs_none_wa": [100*all3[2]/all3[0], 100*none[2]/none[0], ztest(all3[2], all3[0], none[2], none[0])]}
out["robust"] = rob
pk = ("Aug+Sep", "Paid")
out["paid"] = {"base_conv": 100*G[(pk, "A00")][1]/G[(pk, "A00")][0],
               "clickonly_conv": 100*G[(pk, "C08")][1]/G[(pk, "C08")][0],
               "upload_conv": 100*G[(pk, "C07")][1]/G[(pk, "C07")][0]}
json.dump(out, open("outputs/insights_stats.json", "w"), indent=1)

print("trend p", out["dose_trend_p"])
for p in out["pairs"]:
    print(f"{p['label']:16s} conv {p['conv']['with']:.2f} vs {p['conv']['without']:.2f} p={p['conv']['p']:.4f} | WA {p['wa']['with']:.1f} vs {p['wa']['without']:.1f} p={p['wa']['p']:.4f}")
print("upload vs click-only", out["upload_vs_clickonly"])
for d in out["drops"]: print(d["label"], d)
for k, v in rob.items():
    print(k, "all3 vs none conv", [round(x, 4) for x in v["all3_vs_none_conv"]], "wa", [round(x, 4) for x in v["all3_vs_none_wa"]])
    for lab, r in v["pairs"].items(): print("   ", lab, r)
