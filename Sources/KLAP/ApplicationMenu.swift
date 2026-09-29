import AppKit

@MainActor enum ApplicationMenu {
    static func install(application:NSApplication, preview:NSWindow) {
        let menu=NSMenu()
        let appItem=NSMenuItem();let appMenu=NSMenu(title:"KLAP")
        appItem.submenu=appMenu;menu.addItem(appItem)
        let quit=appMenu.addItem(withTitle:"미리보기 닫기",action:#selector(NSWindow.performClose(_:)),keyEquivalent:"q")
        quit.target=preview
        let fileItem=NSMenuItem();let fileMenu=NSMenu(title:"파일")
        fileItem.submenu=fileMenu;menu.addItem(fileItem)
        fileMenu.addItem(withTitle:"창 닫기",action:#selector(NSWindow.performClose(_:)),keyEquivalent:"w")
        application.mainMenu=menu
        if let url=Bundle.main.url(forResource:"KLAP",withExtension:"icns"),let icon=NSImage(contentsOf:url) {
            application.applicationIconImage=icon
        }
    }
}
