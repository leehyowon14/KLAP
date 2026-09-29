import AppKit
import SwiftUI

/// Graphic tonal scale: 0 is white, 50 is the seed, 100 is black.
/// Intermediate stops keep the seed's hue by mixing with white or black.
enum Theme {
    static let stops = [0,5,10,20,30,40,50,60,70,80,90,95,100]
    static func tone(_ level:Double) -> NSColor {
        let t=Double(min(100,max(0,level)))
        let seed:[Double]=[138.0/255,22.0/255,1.0/255]
        let rgb=seed.map { component in
            t <= 50 ? 1 + (component-1)*(t/50) : component*(1-(t-50)/50)
        }
        return NSColor(srgbRed:rgb[0],green:rgb[1],blue:rgb[2],alpha:1)
    }
    static func pair(_ light:Int,_ dark:Int) -> Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            tone(Double(appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? dark : light))
        })
    }
    // Neutral application surfaces are independent of the course palette.
    static func neutral(_ light:CGFloat,_ dark:CGFloat) -> Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            NSColor(white:appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? dark : light,alpha:1)
        })
    }
    static let accent=Color.accentColor
    static let canvas=neutral(0.92,0.12)
    static let surface=neutral(0.96,0.18)
    static let line=neutral(0.72,0.38)
    static let ink=Color.primary
    static let warning=Color(nsColor:NSColor(name:nil) { appearance in
        appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
            ? NSColor(srgbRed:1,green:0.83,blue:0.56,alpha:1)
            : NSColor(srgbRed:0.43,green:0.20,blue:0.01,alpha:1)
    })
    static let warningSurface=Color(nsColor:NSColor(name:nil) { appearance in
        appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
            ? NSColor(srgbRed:0.28,green:0.19,blue:0.08,alpha:1)
            : NSColor(srgbRed:0.89,green:0.85,blue:0.78,alpha:1)
    })
}
