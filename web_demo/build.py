"""Builds one self-contained HTML file from web_demo/ (images, data and engine inlined).
   python3 web_demo/build.py [output.html]   (run from the package root or anywhere)"""
import base64, json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
data_dir = os.path.join(here, '..', 'app', 'assets', 'data')
P = json.load(open(os.path.join(data_dir, 'zapwise_params.json')))
PR = json.load(open(os.path.join(data_dir, 'products.json')))
open(os.path.join(here, 'data.js'), 'w').write('/* generated from app/assets/data by web_demo/build.py */\nwindow.ZW_DATA = ' + json.dumps({'params': P, 'products': PR}, separators=(',', ':')) + ';\n')
s = open(os.path.join(here, 'index.html')).read()
for name in ('data.js', 'engine.js'):
    s = s.replace('<script src="%s"></script>' % name, '<script>\n' + open(os.path.join(here, name)).read() + '\n</script>')
imgs = {'img/' + f: 'data:image/png;base64,' + base64.b64encode(open(os.path.join(here, 'img', f), 'rb').read()).decode()
        for f in os.listdir(os.path.join(here, 'img')) if f.endswith('.png')}
for k, v in imgs.items():
    s = s.replace('src="%s"' % k, 'src="%s"' % v)
hook = """<script>
/* single-file build: the pixel art is embedded; any <img src="img/..."> is swapped for its embedded copy */
var ZW_IMGS = %s;
(function () {
  function fix(el) { var a = el.getAttribute && el.getAttribute('src'); if (a && ZW_IMGS[a]) el.setAttribute('src', ZW_IMGS[a]); }
  new MutationObserver(function (ms) {
    ms.forEach(function (m) {
      if (m.type === 'attributes') fix(m.target);
      m.addedNodes && m.addedNodes.forEach(function (n) { if (n.nodeType !== 1) return; if (n.tagName === 'IMG') fix(n); if (n.querySelectorAll) n.querySelectorAll('img').forEach(fix); });
    });
  }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });
})();
</script>
""" % json.dumps(imgs)
i = s.index('<script>')
s = s[:i] + hook + s[i:]
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, 'zapwise_web.html')
open(out, 'w').write(s)
print('built', out, len(s) // 1024, 'KB')
