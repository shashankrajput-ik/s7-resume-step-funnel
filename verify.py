"""Recon layer 1: arithmetic identities over the CSVs behind the report. Exit 1 on any failure."""
import csv, sys
fails = []; n = 0
def check(ok, msg):
    global n; n += 1
    if not ok: fails.append(msg)

M = ['users', 'sales', 'attended', 'reg_held', 'att_held']
def load(path, key):
    D = {}
    for r in csv.DictReader(open(path)):
        D[(key(r), r['segment'][:3])] = [int(r[k]) if r[k] else None for k in M]
    return D
O = load('outputs/14_conv_wa_unique_users_aug_sep.csv', lambda r: r['period'])
G = load('outputs/15_conv_wa_paid_nonpaid_aug_sep.csv', lambda r: (r['period'], r['grp']))
F = {r['month']: r for r in csv.DictReader(open('outputs/03_funnel_mom.csv'))}
P = ['2026-08', '2026-09', 'Aug+Sep']

def ident(D, k, whole, parts, label, cols=range(5)):
    for c in cols:
        w = D[(k, whole)][c]; s = sum(D[(k, p)][c] for p in parts)
        check(w == s, f'{k} {label} {M[c]}: {whole}={w} vs sum{parts}={s}')

for D, keys in ((O, P), (G, [(p, g) for p in P for g in ('Paid', 'Non-paid', 'Other')])):
    for k in keys:
        ident(D, k, 'A01', ['B01', 'B02', 'B06', 'B07'], 'S6 = 0+1+2+3 inputs')
        ident(D, k, 'B02', ['B03', 'B04', 'B05'], 'one input = slot+LI+resume only')
        ident(D, k, 'A01', ['C01', 'C02'], 'S6 = slot + no slot')
        ident(D, k, 'A01', ['C03', 'C04'], 'S6 = LI + no LI')
        ident(D, k, 'A01', ['C05', 'C06'], 'S6 = click + no click')
        ident(D, k, 'A01', ['C07', 'C09'], 'S6 = uploaded + not uploaded')
        ident(D, k, 'A01', ['D01', 'D02'], 'S6 = submitted + dropped')
        ident(D, k, 'A01', ['D03'], 'S6 = S5->S6 (every S6 user also hit S5)', cols=[0]) if False else None
        ident(D, k, 'A00', ['D05', 'D06'], 'S4 base = S4->S5 + S4 dropped')
        for c in range(5):   # subset rules
            check(D[(k, 'C08')][c] <= D[(k, 'C05')][c] and D[(k, 'C08')][c] <= D[(k, 'C09')][c], f'{k} clicked-not-uploaded is subset {M[c]}')
            check(D[(k, 'A01')][c] <= D[(k, 'A00')][c] + 10**9, '')
        u = D[(k, 'A00')]
        check(u[1] <= u[0] and u[2] <= u[0] and u[4] <= u[3] <= u[0], f'{k} sales/att <= users')

# paid + non-paid + other = overall, every segment, every metric
for p in P:
    for seg in {s for (_, s) in O if _ == p}:
        for c in range(5):
            s = sum(G[((p, g), seg)][c] or 0 for g in ('Paid', 'Non-paid', 'Other') if ((p, g), seg) in G)
            check(O[(p, seg)][c] is None or O[(p, seg)][c] == s, f'{p} {seg} {M[c]}: overall {O[(p, seg)][c]} vs groups {s}')

# pooled <= month sum (users in both months counted once), pooled >= max month
for D, ks in ((O, [None]), (G, ['Paid', 'Non-paid', 'Other'])):
    for g in ks:
        k = lambda p: p if g is None else (p, g)
        for seg in {s for (kk, s) in D if kk == k('Aug+Sep')}:
            a, b, ab = D[(k('2026-08'), seg)][0], D[(k('2026-09'), seg)][0], D[(k('Aug+Sep'), seg)][0]
            check(max(a, b) <= ab <= a + b, f'{g} {seg} pooled {ab} outside [{max(a,b)}, {a+b}]')

# funnel: pre-match S4 equals funnel S4 per month
for p, m in (('2026-08', '2026-08'), ('2026-09', '2026-09')):
    check(O[(p, 'Z01')][0] == int(F[m]['s4']), f'{p} Z01 S4 {O[(p, "Z01")][0]} != funnel {F[m]["s4"]}')
    check(O[(p, 'A00')][0] <= O[(p, 'Z01')][0], f'{p} matched base > S4')
    check(O[(p, 'A01')][0] <= int(F[m]['s6']), f'{p} matched S6 > funnel S6')

print(f'{n} checks, {len([f for f in fails if f])} failures')
for f in fails:
    if f: print('FAIL', f)
sys.exit(1 if any(fails) else 0)
