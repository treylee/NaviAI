import Cocoa
import Vision
import CoreGraphics
import Foundation

// MARK: - Main App Entry Point

class AppDelegate: NSObject, NSApplicationDelegate {
    var controlWindow: ControlWindow!
    var overlayWindow: OverlayWindow!
    var textDetector: TextDetector!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 App launched")
        
        // Setup overlay window
        overlayWindow = OverlayWindow()
        overlayWindow.makeKeyAndOrderFront(nil)
        
        // Setup text detector
        textDetector = TextDetector(overlayWindow: overlayWindow)
        
        // Setup control window
        controlWindow = ControlWindow(textDetector: textDetector)
        controlWindow.makeKeyAndOrderFront(nil)
        
        // Request permissions
        requestScreenRecordingPermission()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func requestScreenRecordingPermission() {
        // Test if we have permission by trying to create a small capture
        let displayID = CGMainDisplayID()
        if CGDisplayCreateImage(displayID) == nil {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = "Please grant permission in System Preferences > Security & Privacy > Screen Recording"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
            }
        } else {
            NSLog("✅ Screen recording permission granted")
        }
    }
}

// MARK: - Control Window
class ControlWindow: NSWindow {
    weak var textDetector: TextDetector?
    
    private var searchField: NSTextField!
    private var urlField: NSTextField!
    private var statusLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var exactMatchCheckbox: NSButton!
    private var caseSensitiveCheckbox: NSButton!
    private var openBrowserButton: NSButton!
    
    init(textDetector: TextDetector) {
        self.textDetector = textDetector
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 330),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Text Detector Overlay"
        self.center()
        
        setupUI()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
        
        // Title Label
        let titleLabel = createLabel(
            text: "Screen Text Detector",
            frame: NSRect(x: 20, y: 280, width: 410, height: 30),
            fontSize: 18,
            weight: .bold
        )
        contentView.addSubview(titleLabel)
        
        // Search Field
        searchField = NSTextField(frame: NSRect(x: 20, y: 230, width: 410, height: 30))
        searchField.placeholderString = "Enter exact text to find on screen"
        contentView.addSubview(searchField)
        
        // Checkboxes
        exactMatchCheckbox = NSButton(checkboxWithTitle: "Exact match only", target: nil, action: nil)
        exactMatchCheckbox.frame = NSRect(x: 20, y: 195, width: 200, height: 25)
        exactMatchCheckbox.state = .off
        contentView.addSubview(exactMatchCheckbox)
        
        caseSensitiveCheckbox = NSButton(checkboxWithTitle: "Case sensitive", target: nil, action: nil)
        caseSensitiveCheckbox.frame = NSRect(x: 230, y: 195, width: 200, height: 25)
        caseSensitiveCheckbox.state = .off
        contentView.addSubview(caseSensitiveCheckbox)
        
        // Detection Buttons
        startButton = NSButton(frame: NSRect(x: 20, y: 140, width: 200, height: 35))
        startButton.title = "Start Detection"
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(startDetection)
        contentView.addSubview(startButton)
        
        stopButton = NSButton(frame: NSRect(x: 230, y: 140, width: 200, height: 35))
        stopButton.title = "Stop Detection"
        stopButton.bezelStyle = .rounded
        stopButton.target = self
        stopButton.action = #selector(stopDetection)
        stopButton.isEnabled = false
        contentView.addSubview(stopButton)
        
        // URL Field
        urlField = NSTextField(frame: NSRect(x: 20, y: 90, width: 410, height: 30))
        urlField.placeholderString = "Enter URL (e.g., https://google.com)"
        urlField.stringValue = "https://google.com"
        contentView.addSubview(urlField)
        
        // Open Browser Button
        openBrowserButton = NSButton(frame: NSRect(x: 20, y: 50, width: 200, height: 35))
        openBrowserButton.title = "Open Browser"
        openBrowserButton.bezelStyle = .rounded
        openBrowserButton.target = self
        openBrowserButton.action = #selector(openBrowser)
        contentView.addSubview(openBrowserButton)
        
        // Status Label
        statusLabel = createLabel(
            text: "Ready - Enter text and click Start",
            frame: NSRect(x: 20, y: 10, width: 410, height: 30),
            fontSize: 12,
            weight: .regular
        )
        statusLabel.maximumNumberOfLines = 2
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)
        
        self.contentView = contentView
    }
    
    private func createLabel(text: String, frame: NSRect, fontSize: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.stringValue = text
        label.font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        label.alignment = .center
        return label
    }
    
    @objc private func openBrowser() {
        var urlString = urlField.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard !urlString.isEmpty else {
            statusLabel.stringValue = "Please enter a URL"
            statusLabel.textColor = .systemRed
            return
        }
        
        // Add https:// if no protocol is specified
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString) else {
            statusLabel.stringValue = "Invalid URL"
            statusLabel.textColor = .systemRed
            return
        }
        
        NSLog("🌐 Opening browser with URL: \(urlString)")
        statusLabel.stringValue = "Opening browser..."
        statusLabel.textColor = .systemBlue
        
        // Open URL in default browser
        NSWorkspace.shared.open(url)
        
        statusLabel.stringValue = "Browser opened: \(urlString)"
        statusLabel.textColor = .systemGreen
        
        // Reset status after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.statusLabel.stringValue = "Ready"
            self?.statusLabel.textColor = .secondaryLabelColor
        }
    }
    
    @objc private func startDetection() {
        let searchText = searchField.stringValue
        guard !searchText.isEmpty else {
            statusLabel.stringValue = "Please enter text to search for"
            statusLabel.textColor = .systemRed
            return
        }
        
        let exactMatch = exactMatchCheckbox.state == .on
        let caseSensitive = caseSensitiveCheckbox.state == .on
        
        textDetector?.startDetecting(
            searchText: searchText,
            exactMatch: exactMatch,
            caseSensitive: caseSensitive
        )
        
        statusLabel.stringValue = "Detecting: \"\(searchText)\""
        statusLabel.textColor = .systemGreen
        startButton.isEnabled = false
        stopButton.isEnabled = true
        searchField.isEnabled = false
        exactMatchCheckbox.isEnabled = false
        caseSensitiveCheckbox.isEnabled = false
    }
    
    @objc private func stopDetection() {
        textDetector?.stopDetecting()
        
        statusLabel.stringValue = "Detection stopped"
        statusLabel.textColor = .secondaryLabelColor
        startButton.isEnabled = true
        stopButton.isEnabled = false
        searchField.isEnabled = true
        exactMatchCheckbox.isEnabled = true
        caseSensitiveCheckbox.isEnabled = true
    }
}

// MARK: - Overlay Window
class OverlayWindow: NSWindow {
    init() {
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Make window transparent and click-through
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar  // Changed from .screenSaver
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.contentView = OverlayView()
    }
    
    func highlightText(at rect: CGRect) {
        (self.contentView as? OverlayView)?.highlightText(at: rect)
    }
    
    func clearOverlay() {
        (self.contentView as? OverlayView)?.clearOverlay()
    }
}

// MARK: - Overlay View
class OverlayView: NSView {
    private var targetRect: CGRect?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let rect = targetRect else { return }
        
        // Create a rounded rectangle path with modern corner radius
        let cornerRadius: CGFloat = min(rect.height / 2, 20) // Dynamic radius based on height
        let roundedPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        // Create gradient colors for modern look
        let primaryColor = NSColor.systemBlue
        let glowColor = NSColor.systemBlue.withAlphaComponent(0.3)
        
        // Draw outer glow effect
        let glowRect = rect.insetBy(dx: -4, dy: -4)
        let glowPath = NSBezierPath(roundedRect: glowRect, xRadius: cornerRadius + 4, yRadius: cornerRadius + 4)
        glowColor.withAlphaComponent(0.2).setFill()
        glowPath.fill()
        
        // Draw main border with gradient effect
        primaryColor.setStroke()
        roundedPath.lineWidth = 2.5
        roundedPath.stroke()
        
        // Semi-transparent fill with gradient
        primaryColor.withAlphaComponent(0.15).setFill()
        roundedPath.fill()
        
        // Add animated-style corner accents for modern look
        let accentLength: CGFloat = 15
        let accentPath = NSBezierPath()
        accentPath.lineWidth = 3.0
        primaryColor.setStroke()
        
        // Top-left accent
        let tlStart = NSPoint(x: rect.minX + cornerRadius, y: rect.minY)
        accentPath.move(to: NSPoint(x: tlStart.x - accentLength, y: tlStart.y))
        accentPath.line(to: tlStart)
        accentPath.appendArc(
            withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 270,
            endAngle: 240,
            clockwise: true
        )
        
        // Top-right accent
        let trStart = NSPoint(x: rect.maxX - cornerRadius, y: rect.minY)
        accentPath.move(to: NSPoint(x: trStart.x + accentLength, y: trStart.y))
        accentPath.line(to: trStart)
        accentPath.appendArc(
            withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 270,
            endAngle: 300,
            clockwise: false
        )
        
        // Bottom-right accent
        let brStart = NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY)
        accentPath.move(to: NSPoint(x: brStart.x + accentLength, y: brStart.y))
        accentPath.line(to: brStart)
        accentPath.appendArc(
            withCenter: NSPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: 90,
            endAngle: 60,
            clockwise: true
        )
        
        // Bottom-left accent
        let blStart = NSPoint(x: rect.minX + cornerRadius, y: rect.maxY)
        accentPath.move(to: NSPoint(x: blStart.x - accentLength, y: blStart.y))
        accentPath.line(to: blStart)
        accentPath.appendArc(
            withCenter: NSPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: 90,
            endAngle: 120,
            clockwise: false
        )
        
        accentPath.stroke()
        
        // Add subtle inner highlight for depth
        let innerRect = rect.insetBy(dx: 1, dy: 1)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)
        NSColor.white.withAlphaComponent(0.1).setStroke()
        innerPath.lineWidth = 0.5
        innerPath.stroke()
    }
    
    func highlightText(at rect: CGRect) {
        targetRect = rect
        self.needsDisplay = true
    }
    
    func clearOverlay() {
        targetRect = nil
        self.needsDisplay = true
    }
}

// MARK: - Text Detector
class TextDetector {
    private weak var overlayWindow: OverlayWindow?
    private var timer: Timer?
    private var searchText: String = ""
    private var exactMatch: Bool = false
    private var caseSensitive: Bool = false
    
    init(overlayWindow: OverlayWindow) {
        self.overlayWindow = overlayWindow
    }
    
    func startDetecting(searchText: String, exactMatch: Bool, caseSensitive: Bool) {
        NSLog("\n========================================")
        NSLog("Starting detection")
        NSLog("Search text: '\(searchText)'")
        NSLog("Exact match: \(exactMatch)")
        NSLog("Case sensitive: \(caseSensitive)")
        NSLog("========================================\n")
        
        self.searchText = caseSensitive ? searchText : searchText.lowercased()
        self.exactMatch = exactMatch
        self.caseSensitive = caseSensitive
        
        // Start periodic detection every 2 seconds
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                self?.detectText()
            }
            
            // Do initial detection immediately
            self?.detectText()
        }
    }
    
    func stopDetecting() {
        NSLog("\n❌ Stopping detection")
        timer?.invalidate()
        timer = nil
        overlayWindow?.clearOverlay()
    }
    
    private func detectText() {
        NSLog("\n🔍 Scanning screen for: '\(searchText)'")
        
        guard let screen = NSScreen.main else {
            NSLog("ERROR: No screen found")
            return
        }
        
        // Capture screen
        let displayID = CGMainDisplayID()
        guard let screenshot = CGDisplayCreateImage(displayID) else {
            NSLog("ERROR: Cannot capture screen - check Screen Recording permission")
            return
        }
        
        let imageWidth = CGFloat(screenshot.width)
        let imageHeight = CGFloat(screenshot.height)
        NSLog("Screenshot captured: \(Int(imageWidth)) x \(Int(imageHeight)) pixels")
        NSLog("Screen frame: \(Int(screen.frame.width)) x \(Int(screen.frame.height)) pixels")
        
        // Check for Retina display scaling
        let scaleFactor = screen.backingScaleFactor
        NSLog("Display scale factor: \(scaleFactor)")
        
        // Create Vision request
        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                NSLog("ERROR: \(error.localizedDescription)")
                return
            }
            
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                NSLog("No text found on screen")
                return
            }
            
            NSLog("Found \(observations.count) text regions")
            
            DispatchQueue.main.async {
                self.processResults(observations, imageSize: CGSize(width: imageWidth, height: imageHeight))
            }
        }
        
        // Configure recognition for best accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false  // Disable for exact matching
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.0  // Detect all text sizes
        
        // Perform text recognition
        let handler = VNImageRequestHandler(cgImage: screenshot, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            NSLog("ERROR performing vision request: \(error.localizedDescription)")
        }
    }
    
    private func processResults(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) {
        // Clear previous overlay
        overlayWindow?.clearOverlay()
        
        var foundMatch = false
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let scaleFactor = screen.backingScaleFactor
        
        // Look through all text
        for (index, observation) in observations.enumerated() {
            guard let recognizedText = observation.topCandidates(1).first?.string else { continue }
            
            // Prepare text for comparison
            let textToCompare = caseSensitive ? recognizedText : recognizedText.lowercased()
            
            // Log detected text (truncated for readability)
            let preview = String(recognizedText.prefix(100))
            NSLog("  [\(index)] \(preview)\(recognizedText.count > 100 ? "..." : "")")
            
            // Check for match
            let isMatch: Bool
            if exactMatch {
                isMatch = textToCompare == searchText
            } else {
                isMatch = textToCompare.contains(searchText)
            }
            
            if isMatch {
                NSLog("\n✅ FOUND MATCH!")
                NSLog("   Full text: '\(recognizedText)'")
                
                // Get bounding box (normalized 0-1 coordinates)
                let box = observation.boundingBox
                
                // Try different Y coordinate approach
                // Vision: box.origin.y = 0 means bottom of image, 1 means top
                // NSWindow coordinate: y = 0 means bottom of screen
                // But our overlay view might be using flipped coordinates
                
                // Simple direct mapping since coordinates are normalized
                let screenX = box.origin.x * screenFrame.width
                let screenWidth = box.width * screenFrame.width
                let screenHeight = box.height * screenFrame.height
                
                // Try NOT flipping Y - maybe the coordinate systems align
                let screenY = box.origin.y * screenFrame.height
                
                let screenRect = CGRect(
                    x: screenX,
                    y: screenY,
                    width: screenWidth,
                    height: screenHeight
                )
                
                NSLog("   Vision box (normalized): x=\(String(format: "%.3f", box.origin.x)), y=\(String(format: "%.3f", box.origin.y)), w=\(String(format: "%.3f", box.width)), h=\(String(format: "%.3f", box.height))")
                NSLog("   Screen rect: x=\(Int(screenRect.minX)), y=\(Int(screenRect.minY)), w=\(Int(screenRect.width)), h=\(Int(screenRect.height))")
                NSLog("   Screen size: \(Int(screenFrame.width)) x \(Int(screenFrame.height))")
                NSLog("   Image size: \(Int(imageSize.width)) x \(Int(imageSize.height))")
                NSLog("   Scale factor: \(scaleFactor)")
                NSLog("   Y calculation: vision_y(\(String(format: "%.3f", box.origin.y))) * screen_height(\(Int(screenFrame.height))) = \(Int(screenY))")
                
                // Highlight the first match
                overlayWindow?.highlightText(at: screenRect)
                foundMatch = true
                break  // Stop after first match
            }
        }
        
        if !foundMatch {
            NSLog("❌ Text '\(searchText)' not found on screen")
        }
    }
}

// Note: Main entry point is in main.swift
