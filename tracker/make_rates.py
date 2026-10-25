"""Build rates.json from the commission schedules in data/.

The Q4 2026 schedule (data/q4_2026_commission_schedule.csv, exported from the carrier
spreadsheet) is what new sales are logged against. The older printed schedule
(data/commission_schedule.csv) is kept so sales saved before Q4 can still be edited.
"""
import csv
import json
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
out = []

for r in csv.DictReader(open(root / 'data' / 'q4_2026_commission_schedule.csv')):
    out.append({
        'c': r['carrier'], 'g': r['product_grouping'], 'n': r['product_name'], 's': r['states'],
        'p': r['pay_years'], 'a': int(r['adv_mo']) if r['adv_mo'] else None,
        'r': r['associate_1'], 'r2': r['associate_2'], 'r3': r['associate_3'],
        'src': 'Q4 2026', 'ref': 'row ' + r['row'],
    })

for r in csv.DictReader(open(root / 'data' / 'commission_schedule.csv')):
    out.append({
        'c': r['carrier'], 'g': r['product_grouping'], 'n': r['product_name'], 's': r['states'],
        'p': r['pay_years'], 'a': int(r['adv_mo']) if r['adv_mo'] else None,
        'r': r['associate_1'], 'r2': r['associate_2'], 'r3': r['associate_3'],
        'src': 'old sheet', 'ref': 'page ' + r['page'], 'old': True,
    })

bad = [o for o in out if not (o['r'].endswith('%') or o['r'].startswith('$'))]
assert not bad, bad[:5]
json.dump(out, open(root / 'tracker' / 'rates.json', 'w'), separators=(',', ':'))
print(len(out), 'rates', sum(1 for o in out if not o.get('old')), 'Q4')
