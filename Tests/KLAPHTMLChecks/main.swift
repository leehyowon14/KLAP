import AppKit
import SwiftUI
import WebKit

let app = NSApplication.shared
let config = WKWebViewConfiguration()
config.websiteDataStore = .nonPersistent()
config.defaultWebpagePreferences.allowsContentJavaScript = false
let web = WKWebView(frame:NSRect(x:0,y:0,width:420,height:40),configuration:config)
var measuredHeight:CGFloat=40
let renderer = BoardHTMLView(html:"",height:Binding(get:{measuredHeight},set:{measuredHeight=$0}))
let coordinator = renderer.makeCoordinator()
precondition(!coordinator.allowsDocument(url:BoardHTMLView.Coordinator.documentURL,type:.other,isMainFrame:true))
final class Check: NSObject, WKNavigationDelegate {
    func webView(_ webView:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping (WKNavigationActionPolicy)->Void) {
        coordinator.webView(webView,decidePolicyFor:action,decisionHandler:decisionHandler)
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        precondition(!coordinator.allowsDocument(url:BoardHTMLView.Coordinator.documentURL,type:.other,isMainFrame:true))
        coordinator.webView(webView,didFinish:navigation)
        webView.evaluateJavaScript("document.body.scrollHeight") { _, error in
        precondition(error == nil)
        webView.evaluateJavaScript("""
        JSON.stringify({color:getComputedStyle(document.getElementById('red')).color,
        background:getComputedStyle(document.getElementById('red')).backgroundColor,
        font:getComputedStyle(document.getElementById('red')).fontFamily,
        script:window.ran === true, count:document.querySelectorAll('td').length,
        links:document.querySelectorAll('a').length, height:document.body.scrollHeight, bottom:document.body.lastElementChild.getBoundingClientRect().bottom, fullHeight:document.documentElement.scrollHeight})
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
            precondition((result["height"] as! Int)>1600)
            precondition(measuredHeight >= CGFloat((result["bottom"] as! NSNumber).doubleValue))
            precondition(measuredHeight >= CGFloat((result["fullHeight"] as! NSNumber).doubleValue))
            print("HTML color, highlight, system font, table, multiline, uncapped height, final paragraph margin and disabled script checks passed")
            exit(0)
        }
        }
    }
}
let check=Check();web.navigationDelegate=check
coordinator.load("""
<p id="red" style="color:red;background-color:yellow;font-family:serif !important">강조</p>
<table><tr><td>A</td><td>B</td></tr></table><p>다음 줄</p>
<p>https://example.com/test</p><script>window.ran=true</script>
""" + String(repeating:"<p>긴 본문 줄 테스트</p>",count:100) + "<p style=\"margin-bottom:37.5px\">** 따라서 마지막 줄</p>",in:web)
for url in [URL(string:"https://example.com/")!,URL(string:"https://klas.kw.ac.kr/other")!,URL(string:"file:///tmp/test")!] {
    precondition(!coordinator.allowsDocument(url:url,type:.other,isMainFrame:true))
}
precondition(!coordinator.allowsDocument(url:BoardHTMLView.Coordinator.documentURL,type:.other,isMainFrame:false))
precondition(!coordinator.allowsDocument(url:BoardHTMLView.Coordinator.documentURL,type:.linkActivated,isMainFrame:true))
DispatchQueue.main.asyncAfter(deadline:.now()+20) { fputs("HTML test timeout\n",stderr);exit(1) }
app.run()
