"""Build commission-tracker.html from template.html, commission.js and rates.json."""
import pathlib
here = pathlib.Path(__file__).parent
page = (here / 'template.html').read_text(encoding='utf-8')
page = page.replace('/*COMMISSION_JS*/', (here / 'commission.js').read_text(encoding='utf-8'))
page = page.replace('/*RATES*/', (here / 'rates.json').read_text(encoding='utf-8'))
import base64
page = page.replace('/*MARBLE*/', 'data:image/jpeg;base64,' + base64.b64encode((here / 'marble.jpg').read_bytes()).decode())
# Team logo (NCC), cropped to its circle from the image the team provided.
logo_uri = 'data:image/jpeg;base64,' + base64.b64encode((here / 'logo.jpg').read_bytes()).decode()
page = page.replace('<!--LOGO-->', '<img class="logo" src="' + logo_uri + '" alt="National Closers Collective logo" width="84" height="84">')
(here / 'commission-tracker.html').write_text(page, encoding='utf-8')
print('built', len(page), 'bytes')
