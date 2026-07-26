import Foundation

/// The page a wandering tab is turned to during a session — never a
/// punishment, always a small encouragement. Written to ~/Bori/ at
/// session start; each visit picks a quote at random in the page itself.
enum Interlude {
    struct Quote: Codable {
        let text: String
        let who: String
    }

    static let quotes: [Quote] = [
        Quote(text: "Nothing will work unless you do.", who: "Maya Angelou"),
        Quote(text: "The most effective way to do it, is to do it.", who: "Amelia Earhart"),
        Quote(text: "To create one's own world takes courage.", who: "Georgia O'Keeffe"),
        Quote(text: "First forget inspiration. Habit is more dependable.", who: "Octavia E. Butler"),
        Quote(text: "How we spend our days is, of course, how we spend our lives.", who: "Annie Dillard"),
        Quote(text: "Tell me, what is it you plan to do with your one wild and precious life?", who: "Mary Oliver"),
        Quote(text: "Real change, enduring change, happens one step at a time.", who: "Ruth Bader Ginsburg"),
        Quote(text: "I long to accomplish a great and noble task, but it is my chief duty to accomplish small tasks as if they were great and noble.", who: "Helen Keller"),
        Quote(text: "When I dare to be powerful, to use my strength in the service of my vision, then it becomes less and less important whether I am afraid.", who: "Audre Lorde"),
        Quote(text: "There are years that ask questions and years that answer.", who: "Zora Neale Hurston"),
        Quote(text: "Nothing in life is to be feared, it is only to be understood.", who: "Marie Curie"),
        Quote(text: "Almost everything will work again if you unplug it for a few minutes, including you.", who: "Anne Lamott"),
        Quote(text: "The most damaging phrase in the language is: 'We've always done it this way.'", who: "Grace Hopper"),
        Quote(text: "If there's a book that you want to read, but it hasn't been written yet, then you must write it.", who: "Toni Morrison"),
        Quote(text: "It is not that we have a short time to live, but that we waste a lot of it.", who: "Seneca"),
        Quote(text: "The art of being wise is the art of knowing what to overlook.", who: "William James"),
    ]

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Bori")
            .appendingPathComponent("interlude.html")
    }

    /// `endsText` is the already-formatted session end, e.g. "3:40 p.m."
    static func write(endsText: String) {
        let quotesJSON: String
        if let data = try? JSONEncoder().encode(quotes),
           let text = String(data: data, encoding: .utf8) {
            quotesJSON = text
        } else {
            quotesJSON = "[]"
        }
        let html = """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>An interlude</title>
        <style>\(PanelHTML.css)</style>
        <style>
          html, body { margin: 0; padding: 0; }
          body {
            background: var(--bg); color: var(--ink);
            font-family: var(--font-serif);
            min-height: 100vh; display: flex;
            align-items: center; justify-content: center;
          }
          .column { max-width: 460px; padding: 40px 28px; text-align: center; }
          .screen { width: 260px; height: 161px; margin: 0 auto 44px; }
          .quote { font-size: 23px; line-height: 1.5; font-weight: 500; }
          .who { margin-top: 20px; font-size: 15px; color: var(--muted); }
          .who .dash { color: var(--amber); }
          .ends { margin-top: 48px; font-size: 13px; color: var(--muted); }
        </style>
        </head>
        <body>
          <div class="column">
            <div class="screen" id="screen"></div>
            <div class="quote" id="quote"></div>
            <div class="who"><span class="dash">—</span> <span id="who"></span></div>
            <div class="ends">This page was put away for now. The session ends at \(endsText).</div>
          </div>
          <script>\(PanelHTML.js)</script>
          <script>
            const mode = matchMedia('(prefers-color-scheme: dark)');
            const apply = () => document.documentElement.setAttribute('data-mode', mode.matches ? 'dark' : 'light');
            mode.addEventListener('change', apply);
            apply();
            renderBori(document.getElementById('screen'), 'sleep');
            const QUOTES = \(quotesJSON);
            const pick = QUOTES[Math.floor(Math.random() * QUOTES.length)];
            document.getElementById('quote').textContent = '\\u201C' + pick.text + '\\u201D';
            document.getElementById('who').textContent = pick.who;
          </script>
        </body>
        </html>
        """
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? html.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
