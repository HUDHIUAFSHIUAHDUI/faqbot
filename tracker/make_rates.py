"""Build rates.json from the commission schedules in data/.

The OE 2026 schedule (data/oe_2026_commission_schedule.csv, exported from the carrier
spreadsheet) is what new sales are logged against. The Q4 2026 schedule and the older printed
schedule are kept, marked old, so sales saved against them can still be edited at their rates.
"""
import csv
import json
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
out = []

for r in csv.DictReader(open(root / 'data' / 'oe_2026_commission_schedule.csv', encoding='utf-8')):
    out.append({
        'c': r['carrier'], 'g': r['product_grouping'], 'n': r['product_name'], 's': r['states'],
        'p': r['pay_years'], 'a': int(r['adv_mo']) if r['adv_mo'] else None,
        'r': r['associate_1'], 'r2': r['associate_2'], 'r3': r['associate_3'],
        'src': 'OE 2026', 'ref': 'row ' + r['row'],
    })

for r in csv.DictReader(open(root / 'data' / 'q4_2026_commission_schedule.csv', encoding='utf-8')):
    out.append({
        'c': r['carrier'], 'g': r['product_grouping'], 'n': r['product_name'], 's': r['states'],
        'p': r['pay_years'], 'a': int(r['adv_mo']) if r['adv_mo'] else None,
        'r': r['associate_1'], 'r2': r['associate_2'], 'r3': r['associate_3'],
        'src': 'Q4 2026', 'ref': 'row ' + r['row'], 'old': True,
    })

for r in csv.DictReader(open(root / 'data' / 'commission_schedule.csv', encoding='utf-8')):
    out.append({
        'c': r['carrier'], 'g': r['product_grouping'], 'n': r['product_name'], 's': r['states'],
        'p': r['pay_years'], 'a': int(r['adv_mo']) if r['adv_mo'] else None,
        'r': r['associate_1'], 'r2': r['associate_2'], 'r3': r['associate_3'],
        'src': 'old sheet', 'ref': 'page ' + r['page'], 'old': True,
    })

bad = [o for o in out if not (o['r'].endswith('%') or o['r'].startswith('$'))]
assert not bad, bad[:5]
json.dump(out, open(root / 'tracker' / 'rates.json', 'w', encoding='utf-8'), separators=(',', ':'))
print(len(out), 'rates', sum(1 for o in out if not o.get('old')), 'current (OE 2026)')
