import Foundation
import CoreGraphics

public enum MenuPanelPlacement {
    public static func frame(anchor: CGRect, visibleScreen: CGRect, size: CGSize) -> CGRect {
        let margin: CGFloat = 8
        let width = min(size.width, max(0, visibleScreen.width - margin * 2))
        let height = min(size.height, max(0, visibleScreen.height - margin * 2))
        let x = min(max(anchor.midX - width / 2, visibleScreen.minX + margin), visibleScreen.maxX - width - margin)
        let top = min(anchor.minY - 4, visibleScreen.maxY - 4)
        let y = max(visibleScreen.minY + margin, top - height)
        return CGRect(x:x,y:y,width:width,height:height)
    }
}
