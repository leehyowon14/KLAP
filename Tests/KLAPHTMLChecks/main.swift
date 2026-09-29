import AppKit
import SwiftUI
import WebKit

let app = NSApplication.shared
let config = WKWebViewConfiguration()
config.websiteDataStore = .nonPersistent()
config.defaultWebpagePreferences.allowsContentJavaScript = false
let web = WKWebView(frame:NSRect(x:0,y:0,width:420,height:40),configuration:config)
final class Check: NSObject, WKNavigationDelegate {
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        webView.evaluateJavaScript(BoardHTMLView.preparationScript) { _, error in
        precondition(error == nil)
        webView.evaluateJavaScript("""
        JSON.stringify({color:getComputedStyle(document.getElementById('red')).color,
        background:getComputedStyle(document.getElementById('red')).backgroundColor,
        font:getComputedStyle(document.getElementById('red')).fontFamily,
        script:window.ran === true, count:document.querySelectorAll('td').length,
        links:document.querySelectorAll('a').length, height:document.body.scrollHeight})
        """) { value,error in
            precondition(error == nil)
            let data=(value as! String).data(using:.utf8)!
            let result=try! JSONSerialization.jsonObject(with:data) as! [String:Any]
            precondition(result["color"] as? String == "rgb(255, 0, 0)")
            precondition(result["background"] as? String == "rgb(255, 255, 0)")
            precondition((result["font"] as! String).contains("-apple-system"))
            precondition(result["script"] as? Bool == false)
            precondition(result["links"] as? Int == 1)
            precondition(result["count"] as? Int == 2)
            precondition((result["height"] as! Int)>40)
            print("HTML color, highlight, system font, table, multiline and disabled script checks passed")
            exit(0)
        }
        }
    }
}
let check=Check();web.navigationDelegate=check
web.loadHTMLString(BoardHTMLView.document("""
<p id="red" style="color:red;background-color:yellow;font-family:serif !important">강조</p>
<table><tr><td>A</td><td>B</td></tr></table><p>다음 줄</p>
<p>https://example.com/test</p><script>window.ran=true</script>
"""),baseURL:URL(string:"https://klas.kw.ac.kr/"))
DispatchQueue.main.asyncAfter(deadline:.now()+20) { fputs("HTML test timeout\n",stderr);exit(1) }
app.run()
