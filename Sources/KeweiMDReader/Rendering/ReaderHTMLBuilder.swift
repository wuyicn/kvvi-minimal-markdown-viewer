import Foundation

struct ReaderHTMLBuilder: Sendable {
    func build(markdown: String) throws -> String {
        guard let jsURL = Bundle.module.url(
            forResource: "markdown-it.umd.min",
            withExtension: "js"
        ), let cssURL = Bundle.module.url(
            forResource: "reader",
            withExtension: "css"
        ), let renderer = try? String(contentsOf: jsURL, encoding: .utf8),
           let css = try? String(contentsOf: cssURL, encoding: .utf8),
           let encodedData = try? JSONSerialization.data(withJSONObject: [markdown]),
           var encoded = String(data: encodedData, encoding: .utf8) else {
            throw ReaderError.renderFailed
        }

        encoded.removeFirst()
        encoded.removeLast()
        encoded = encoded
            .replacingOccurrences(of: "<", with: #"\u003C"#)
            .replacingOccurrences(of: ">", with: #"\u003E"#)
            .replacingOccurrences(of: "&", with: #"\u0026"#)
            .replacingOccurrences(of: "\u{2028}", with: #"\u2028"#)
            .replacingOccurrences(of: "\u{2029}", with: #"\u2029"#)

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy"
                content="default-src 'none'; img-src kewei-image: data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
          <style>\(css)</style>
        </head>
        <body>
          <main id="content"></main>
          <script>\(renderer)</script>
          <script>
          const source = \(encoded);
          const md = window.markdownit({ html: false, linkify: true, typographer: true, breaks: false });
          const defaultImage = md.renderer.rules.image;
          md.renderer.rules.image = function(tokens, index, options, env, self) {
            const src = tokens[index].attrGet('src') || '';
            if (/^https?:/i.test(src) || /^(javascript|file|data):/i.test(src)) {
              return '<span class="remote-image">[远程图片未加载]</span>';
            }
            tokens[index].attrSet('src', 'kewei-image://local/' + encodeURIComponent(src));
            return defaultImage(tokens, index, options, env, self);
          };
          function renderTaskLists(html) {
            return html
              .replace(/<li>\\s*\\[ \\]\\s*/gi, '<li class="task-item"><input type="checkbox" disabled> ')
              .replace(/<li>\\s*\\[[xX]\\]\\s*/g, '<li class="task-item"><input type="checkbox" checked disabled> ');
          }
          const content = document.getElementById('content');
          content.innerHTML = renderTaskLists(md.render(source));
          content.querySelectorAll('img').forEach((image) => {
            image.addEventListener('error', () => {
              const replacement = document.createElement('span');
              replacement.className = 'missing-image';
              replacement.textContent = '[图片无法显示]';
              image.replaceWith(replacement);
            });
          });
          </script>
        </body>
        </html>
        """
    }
}
