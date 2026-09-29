import AppKit
import SwiftUI

/// Graphic tonal scale: 0 is white, 50 is the seed, 100 is black.
/// Intermediate stops keep the seed's hue by mixing with white or black.
enum Theme {
    static let stops = [0,5,10,20,30,40,50,60,70,80,90,95,100]
    static func tone(_ level:Int) -> NSColor {
        let t=Double(min(100,max(0,level)))
        let seed:[Double]=[138.0/255,22.0/255,1.0/255]
        let rgb=seed.map { component in
            t <= 50 ? 1 + (component-1)*(t/50) : component*(1-(t-50)/50)
        }
        return NSColor(srgbRed:rgb[0],green:rgb[1],blue:rgb[2],alpha:1)
    }
    static func pair(_ light:Int,_ dark:Int) -> Color {
        Color(nsColor:NSColor(name:nil) { appearance in
            tone(appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? dark : light)
        })
    }
    static let accent=pair(50,20)
    static let canvas=pair(10,95)
    static let surface=pair(5,90)
    static let line=pair(20,60)
    static let ink=pair(90,5)
    static let warning=pair(70,10)
    static let warningSurface=pair(10,80)
    static let tones:[Color] = [40,50,60,70].map { pair($0,$0) }
}
