import AppKit
import SwiftUI

struct ThemeColors {
    let id: String
    let name: String
    let background: NSColor
    let primary: NSColor
    let secondary: NSColor

    var swiftUIBackground: Color { Color(background) }
    var swiftUIPrimary: Color { Color(primary) }
    var swiftUISecondary: Color { Color(secondary) }

    static let all: [ThemeColors] = [redAlarm, blueCalm, greenFresh, monoMinimal]

    static let redAlarm = ThemeColors(
        id: "red-alarm",
        name: "深红警告",
        background: NSColor(red: 8/255, green: 0/255, blue: 14/255, alpha: 1),
        primary: NSColor(red: 1.0, green: 52/255, blue: 52/255, alpha: 1),
        secondary: NSColor(red: 1.0, green: 162/255, blue: 162/255, alpha: 1)
    )

    static let blueCalm = ThemeColors(
        id: "blue-calm",
        name: "深蓝平静",
        background: NSColor(red: 2/255, green: 10/255, blue: 26/255, alpha: 1),
        primary: NSColor(red: 74/255, green: 158/255, blue: 1.0, alpha: 1),
        secondary: NSColor(red: 160/255, green: 200/255, blue: 1.0, alpha: 1)
    )

    static let greenFresh = ThemeColors(
        id: "green-fresh",
        name: "深绿清新",
        background: NSColor(red: 2/255, green: 16/255, blue: 8/255, alpha: 1),
        primary: NSColor(red: 61/255, green: 196/255, blue: 106/255, alpha: 1),
        secondary: NSColor(red: 160/255, green: 230/255, blue: 180/255, alpha: 1)
    )

    static let monoMinimal = ThemeColors(
        id: "mono-minimal",
        name: "黑白极简",
        background: NSColor(white: 0.067, alpha: 1),
        primary: NSColor(white: 0.93, alpha: 1),
        secondary: NSColor(white: 0.70, alpha: 1)
    )

    static func find(_ id: String) -> ThemeColors {
        return all.first { $0.id == id } ?? redAlarm
    }
}
