"""Build commission-tracker.html from template.html, commission.js and rates.json."""
import pathlib
here = pathlib.Path(__file__).parent
page = (here / 'template.html').read_text(encoding='utf-8')
page = page.replace('/*COMMISSION_JS*/', (here / 'commission.js').read_text(encoding='utf-8'))
page = page.replace('/*RATES*/', (here / 'rates.json').read_text(encoding='utf-8'))
import base64
page = page.replace('/*MARBLE*/', 'data:image/jpeg;base64,' + base64.b64encode((here / 'marble.jpg').read_bytes()).decode())
page = page.replace('<!--LOGO-->', (here / 'logo.svg').read_text(encoding='utf-8'))
(here / 'commission-tracker.html').write_text(page, encoding='utf-8')
print('built', len(page), 'bytes')
