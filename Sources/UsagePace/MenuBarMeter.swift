import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import PaceCore

enum MenuBarMeter {
    static func color(for signal: PaceSignal) -> NSColor {
        switch signal {
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .red: return .systemRed
        case .unavailable: return .secondaryLabelColor
        }
    }
    /// A native, non-template image retains the pacing color in both menu bar appearances.
    static func image(used: Double?, expected: Double?, signal: PaceSignal) -> NSImage {
        let image = NSImage(size: NSSize(width: 38, height: 18), flipped: false) { _ in
            let bounds = NSRect(x: 1, y: 3, width: 36, height: 12)
            let outline = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
            NSColor.labelColor.withAlphaComponent(0.12).setFill()
            outline.fill()
            NSColor.labelColor.withAlphaComponent(0.5).setStroke()
            outline.lineWidth = 1
            outline.stroke()
            let color = color(for: signal)
            if let used, used.isFinite {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 2, yRadius: 2).addClip()
                color.withAlphaComponent(signal == .unavailable ? 0.4 : 1).setFill()
                NSRect(x: 3, y: 5, width: 32 * min(100, max(0, used)) / 100, height: 8).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            if let expected, expected.isFinite {
                let x = 3 + 32 * min(100, max(0, expected)) / 100
                NSColor.labelColor.withAlphaComponent(0.85).setFill()
                let marker = NSRect(x: min(34, x), y: 2, width: 1.5, height: 14)
                NSColor.black.setFill()
                marker.insetBy(dx: -0.5, dy: 0).fill()
                NSColor.white.setFill()
                marker.fill()
            } else {
                NSColor.secondaryLabelColor.setFill()
                NSBezierPath(ovalIn: NSRect(x: 17, y: 7, width: 4, height: 4)).fill()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Quota used, colored by pacing"
        return image
    }
}

@MainActor
enum AccountLogo {
    static func url(_ id: Int) -> URL {
        Locations.root.appendingPathComponent("account-logos", isDirectory: true)
            .appendingPathComponent("\(id).png")
    }

    static func image(_ id: Int, isClaude: Bool) -> NSImage? {
        NSImage(contentsOf: url(id)) ?? NSImage(
            systemSymbolName: isClaude ? "briefcase" : "house",
            accessibilityDescription: isClaude ? "Work account" : "Personal account"
        )?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))
    }

    static func choose(_ id: Int) throws -> Bool {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Use Logo"
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return false }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let format = CGImageSourceGetType(source) as String?,
              [UTType.png.identifier, UTType.jpeg.identifier].contains(format),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 96
              ] as CFDictionary),
              let data = NSBitmapImageRep(cgImage: thumbnail).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let destination = url(id)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        return true
    }

    static func readout(id: Int, isClaude: Bool, used: Double?, expected: Double?, signal: PaceSignal) -> NSImage {
        let logo = image(id, isClaude: isClaude)
        let meter = MenuBarMeter.image(used: used, expected: expected, signal: signal)
        return NSImage(size: NSSize(width: 57, height: 18), flipped: false) { _ in
            if let logo, logo.size.width > 0, logo.size.height > 0 {
                let scale = min(15 / logo.size.width, 15 / logo.size.height)
                let width = logo.size.width * scale
                let height = logo.size.height * scale
                logo.draw(in: NSRect(x: (16 - width) / 2, y: (18 - height) / 2, width: width, height: height))
            }
            meter.draw(in: NSRect(x: 19, y: 0, width: 38, height: 18))
            return true
        }
    }
}

struct AccountLogoPicker: View {
    let id: Int
    let isClaude: Bool
    let onChange: () -> Void
    @State private var customLogo = false
    @State private var showError = false

    var body: some View {
        HStack {
            if let logo = AccountLogo.image(id, isClaude: isClaude) {
                Image(nsImage: logo).resizable().scaledToFit().frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
            Button("Choose Logo…") {
                do {
                    if try AccountLogo.choose(id) {
                        customLogo = true
                        onChange()
                    }
                } catch { showError = true }
            }.help("Choose a JPG or PNG for this account")
            if customLogo {
                Button("Reset Logo") {
                    do {
                        try FileManager.default.removeItem(at: AccountLogo.url(id))
                        customLogo = false
                        onChange()
                    } catch { showError = true }
                }
            }
        }
        .onAppear { customLogo = FileManager.default.fileExists(atPath: AccountLogo.url(id).path) }
        .alert("Couldn’t update the account logo", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose a readable JPG or PNG, or try again.")
        }
    }
}
