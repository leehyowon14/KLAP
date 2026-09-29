import AppKit

@MainActor enum ApplicationMenu {
    static func install(application:NSApplication) {
        let menu=NSMenu()
        let appItem=NSMenuItem();let appMenu=NSMenu(title:"KLAP")
        appItem.submenu=appMenu;menu.addItem(appItem)
        let quit=appMenu.addItem(withTitle:"KLAP 종료",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        quit.target=application
        let fileItem=NSMenuItem();let fileMenu=NSMenu(title:"파일")
        fileItem.submenu=fileMenu;menu.addItem(fileItem)
        fileMenu.addItem(withTitle:"창 닫기",action:#selector(NSWindow.performClose(_:)),keyEquivalent:"w")
        application.mainMenu=menu
        if let url=Bundle.main.url(forResource:"KLAP",withExtension:"icns"),let icon=NSImage(contentsOf:url) {
            application.applicationIconImage=icon
        }
    }
}
