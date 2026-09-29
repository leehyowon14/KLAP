import SwiftUI
import WebKit
import AppKit

/// Renders board formatting without giving the document script or network access.
struct BoardHTMLView: NSViewRepresentable {
    let html: String
    @Binding var height: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.loaded != html else { return }
        context.coordinator.loaded = html
        view.loadHTMLString(Self.document(html), baseURL: URL(string: "https://klas.kw.ac.kr/"))
    }
    static func document(_ body: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src 'none'; base-uri 'none'; form-action 'none'">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        html,body { margin:0; padding:0; background:transparent; }
        body { font-size:13px; line-height:1.65; overflow-wrap:anywhere; }
        body,body * { font-family:-apple-system,BlinkMacSystemFont,sans-serif !important; }
        img { max-width:100%; height:auto; }
        table { max-width:100%; } a { color: -apple-system-blue; }
        </style></head><body>\(body)</body></html>
        """
    }
    static let preparationScript = #"""
    document.querySelectorAll('body, body *').forEach(e => e.style.setProperty('font-family','-apple-system, BlinkMacSystemFont, sans-serif','important'));
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const nodes = []; while (walker.nextNode()) nodes.push(walker.currentNode);
    for (const node of nodes) {
        if (node.parentElement.closest('a,script,style,textarea')) continue;
        const regex = /https?:\/\/[^\s<>"']+/g;
        const text = node.textContent; const matches = [...text.matchAll(regex)];
        if (!matches.length) continue;
        const fragment = document.createDocumentFragment(); let offset = 0;
        for (const match of matches) {
            fragment.append(document.createTextNode(text.slice(offset,match.index)));
            const link = document.createElement('a'); link.textContent = match[0]; link.href = match[0];
            fragment.append(link); offset = match.index + match[0].length;
        }
        fragment.append(document.createTextNode(text.slice(offset))); node.replaceWith(fragment);
    }
    Math.max(40,document.body.scrollHeight)
    """#
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: BoardHTMLView
        var loaded: String?
        init(_ parent: BoardHTMLView) { self.parent = parent }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // App-owned evaluation remains available with page JavaScript disabled.
            webView.evaluateJavaScript(BoardHTMLView.preparationScript) { [weak self] value, _ in
                guard let self, let number = value as? NSNumber else { return }
                self.parent.height = min(1600, max(40, CGFloat(number.doubleValue)))
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated {
                if let url = action.request.url, ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
            } else {
                decisionHandler(action.request.url?.scheme == "about" ? .allow : .cancel)
            }
        }
    }
}
