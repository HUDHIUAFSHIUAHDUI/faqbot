"""Build commission-tracker.html from template.html, commission.js and rates.json."""
import pathlib
here = pathlib.Path(__file__).parent
page = (here / 'template.html').read_text()
page = page.replace('/*COMMISSION_JS*/', (here / 'commission.js').read_text())
page = page.replace('/*RATES*/', (here / 'rates.json').read_text())
(here / 'commission-tracker.html').write_text(page)
print('built', len(page), 'bytes')
