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
    private var autoClickCheckbox: NSButton!
    private var openBrowserButton: NSButton!
    private var clickFoundTextButton: NSButton!
    
    init(textDetector: TextDetector) {
        self.textDetector = textDetector
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Navi Control Panel"
        self.center()
        
        setupUI()
    }
    
    private func setupUI() {
        let contentView = NSView(frame: self.contentRect(forFrameRect: self.frame))
        
        // Title Label
        let titleLabel = createLabel(
            text: "Navi Control Panel",
            frame: NSRect(x: 20, y: 350, width: 410, height: 30),
            fontSize: 18,
            weight: .bold
        )
        contentView.addSubview(titleLabel)
        
        // Search Field
        searchField = NSTextField(frame: NSRect(x: 20, y: 300, width: 410, height: 30))
        searchField.placeholderString = "Enter text to find on screen"
        contentView.addSubview(searchField)
        
        // Checkboxes
        exactMatchCheckbox = NSButton(checkboxWithTitle: "Exact match only", target: nil, action: nil)
        exactMatchCheckbox.frame = NSRect(x: 20, y: 265, width: 140, height: 25)
        exactMatchCheckbox.state = .off
        contentView.addSubview(exactMatchCheckbox)
        
        caseSensitiveCheckbox = NSButton(checkboxWithTitle: "Case sensitive", target: nil, action: nil)
        caseSensitiveCheckbox.frame = NSRect(x: 165, y: 265, width: 120, height: 25)
        caseSensitiveCheckbox.state = .off
        contentView.addSubview(caseSensitiveCheckbox)
        
        autoClickCheckbox = NSButton(checkboxWithTitle: "Auto-click", target: nil, action: nil)
        autoClickCheckbox.frame = NSRect(x: 290, y: 265, width: 140, height: 25)
        autoClickCheckbox.state = .off
        autoClickCheckbox.toolTip = "Automatically click when text is found"
        contentView.addSubview(autoClickCheckbox)
        
        // Detection Buttons
        startButton = NSButton(frame: NSRect(x: 20, y: 210, width: 200, height: 35))
        startButton.title = "Start Detection"
        startButton.bezelStyle = .rounded
        startButton.target = self
        startButton.action = #selector(startDetection)
        contentView.addSubview(startButton)
        
        stopButton = NSButton(frame: NSRect(x: 230, y: 210, width: 200, height: 35))
        stopButton.title = "Stop Detection"
        stopButton.bezelStyle = .rounded
        stopButton.target = self
        stopButton.action = #selector(stopDetection)
        stopButton.isEnabled = false
        contentView.addSubview(stopButton)
        
        // Click Found Text Button
        clickFoundTextButton = NSButton(frame: NSRect(x: 20, y: 165, width: 410, height: 35))
        clickFoundTextButton.title = "🖱️ Click Found Text"
        clickFoundTextButton.bezelStyle = .rounded
        clickFoundTextButton.target = self
        clickFoundTextButton.action = #selector(clickFoundText)
        clickFoundTextButton.isEnabled = false
        clickFoundTextButton.toolTip = "Click on the last found text location"
        contentView.addSubview(clickFoundTextButton)
        
        // URL Field
        urlField = NSTextField(frame: NSRect(x: 20, y: 110, width: 410, height: 30))
        urlField.placeholderString = "Enter URL (e.g., https://google.com)"
        urlField.stringValue = "https://google.com"
        contentView.addSubview(urlField)
        
        // Open Browser Button
        openBrowserButton = NSButton(frame: NSRect(x: 20, y: 70, width: 200, height: 35))
        openBrowserButton.title = "Open Browser"
        openBrowserButton.bezelStyle = .rounded
        openBrowserButton.target = self
        openBrowserButton.action = #selector(openBrowser)
        contentView.addSubview(openBrowserButton)
        
        // Status Label
        statusLabel = createLabel(
            text: "Ready",
            frame: NSRect(x: 20, y: 10, width: 410, height: 50),
            fontSize: 12,
            weight: .regular
        )
        statusLabel.maximumNumberOfLines = 3
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
    
    @objc private func startDetection() {
        let searchText = searchField.stringValue
        guard !searchText.isEmpty else {
            statusLabel.stringValue = "Please enter text to search for"
            statusLabel.textColor = .systemRed
            return
        }
        
        let exactMatch = exactMatchCheckbox.state == .on
        let caseSensitive = caseSensitiveCheckbox.state == .on
        let autoClick = autoClickCheckbox.state == .on
        
        textDetector?.startDetecting(
            searchText: searchText,
            exactMatch: exactMatch,
            caseSensitive: caseSensitive,
            autoClick: autoClick
        )
        
        statusLabel.stringValue = "Detecting: \"\(searchText)\"\(autoClick ? " (Auto-click ON)" : "")"
        statusLabel.textColor = .systemGreen
        startButton.isEnabled = false
        stopButton.isEnabled = true
        clickFoundTextButton.isEnabled = true
        searchField.isEnabled = false
        exactMatchCheckbox.isEnabled = false
        caseSensitiveCheckbox.isEnabled = false
        autoClickCheckbox.isEnabled = false
    }
    
    @objc private func stopDetection() {
        textDetector?.stopDetecting()
        
        statusLabel.stringValue = "Detection stopped"
        statusLabel.textColor = .secondaryLabelColor
        startButton.isEnabled = true
        stopButton.isEnabled = false
        clickFoundTextButton.isEnabled = false
        searchField.isEnabled = true
        exactMatchCheckbox.isEnabled = true
        caseSensitiveCheckbox.isEnabled = true
        autoClickCheckbox.isEnabled = true
    }
    
    @objc private func clickFoundText() {
        NSLog("🖱️ Manual click requested")
        textDetector?.clickLastFoundText()
        
        statusLabel.stringValue = "Clicked on found text"
        statusLabel.textColor = .systemGreen
        
        // Reset status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.statusLabel.stringValue = "Ready"
            self?.statusLabel.textColor = .secondaryLabelColor
        }
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
        self.level = .statusBar
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.contentView = OverlayView()
    }
    
    func highlightText(at rect: CGRect) {
        (self.contentView as? OverlayView)?.highlightText(at: rect)
    }
    
    func showClickPoint(at point: CGPoint) {
        (self.contentView as? OverlayView)?.showClickPoint(at: point)
    }
    
    func clearOverlay() {
        (self.contentView as? OverlayView)?.clearOverlay()
    }
}

// MARK: - Overlay View
class OverlayView: NSView {
    private var targetRect: CGRect?
    private var clickPoint: CGPoint?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw text highlight if present
        if let rect = targetRect {
            // Expand the rect slightly for better visibility
            let expandedRect = rect.insetBy(dx: -8, dy: -6)
            
            // Create a rounded rectangle (pill shape for thin text)
            let cornerRadius: CGFloat = expandedRect.height / 2.5
            let roundedPath = NSBezierPath(roundedRect: expandedRect, xRadius: cornerRadius, yRadius: cornerRadius)
            
            // Simple modern design - just border and subtle fill
            // Use a nice blue color
            let highlightColor = NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
            
            // Draw the fill first
            highlightColor.withAlphaComponent(0.1).setFill()
            roundedPath.fill()
            
            // Draw the border
            highlightColor.setStroke()
            roundedPath.lineWidth = 2.0
            roundedPath.stroke()
            
            // Add a simple dot indicator at the center-left
            let dotRadius: CGFloat = 4
            let dotPath = NSBezierPath()
            dotPath.appendOval(in: NSRect(
                x: expandedRect.minX - dotRadius - 5,
                y: expandedRect.midY - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            highlightColor.setFill()
            dotPath.fill()
        }
        
        // Draw click point indicator if present
        if let point = clickPoint {
            // Draw a large red circle at the click point
            let clickRadius: CGFloat = 20
            
            // Outer circle (red border)
            let outerCircle = NSBezierPath()
            outerCircle.appendOval(in: NSRect(
                x: point.x - clickRadius,
                y: point.y - clickRadius,
                width: clickRadius * 2,
                height: clickRadius * 2
            ))
            
            NSColor.red.setStroke()
            outerCircle.lineWidth = 3.0
            outerCircle.stroke()
            
            // Inner filled circle
            NSColor.red.withAlphaComponent(0.3).setFill()
            outerCircle.fill()
            
            // Center dot
            let centerDot = NSBezierPath()
            centerDot.appendOval(in: NSRect(
                x: point.x - 3,
                y: point.y - 3,
                width: 6,
                height: 6
            ))
            NSColor.red.setFill()
            centerDot.fill()
            
            // Draw crosshairs for precise position
            let crosshair = NSBezierPath()
            crosshair.move(to: NSPoint(x: point.x - 30, y: point.y))
            crosshair.line(to: NSPoint(x: point.x - clickRadius - 3, y: point.y))
            crosshair.move(to: NSPoint(x: point.x + clickRadius + 3, y: point.y))
            crosshair.line(to: NSPoint(x: point.x + 30, y: point.y))
            crosshair.move(to: NSPoint(x: point.x, y: point.y - 30))
            crosshair.line(to: NSPoint(x: point.x, y: point.y - clickRadius - 3))
            crosshair.move(to: NSPoint(x: point.x, y: point.y + clickRadius + 3))
            crosshair.line(to: NSPoint(x: point.x, y: point.y + 30))
            
            NSColor.red.setStroke()
            crosshair.lineWidth = 1.0
            crosshair.stroke()
            
            // Draw coordinates text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.red.withAlphaComponent(0.8)
            ]
            let coordText = "(\(Int(point.x)), \(Int(point.y)))"
            let textSize = coordText.size(withAttributes: attributes)
            let textRect = NSRect(x: point.x + 25, y: point.y + 25, width: textSize.width + 4, height: textSize.height + 2)
            
            // Draw background for text
            NSColor.red.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: textRect, xRadius: 2, yRadius: 2).fill()
            
            // Draw coordinate text
            coordText.draw(in: textRect.insetBy(dx: 2, dy: 1), withAttributes: attributes)
        }
    }
    
    func highlightText(at rect: CGRect) {
        targetRect = rect
        self.needsDisplay = true
    }
    
    func showClickPoint(at point: CGPoint) {
        clickPoint = point
        self.needsDisplay = true
        
        // Clear the click point after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.clickPoint = nil
            self?.needsDisplay = true
        }
    }
    
    func clearOverlay() {
        targetRect = nil
        clickPoint = nil
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
    private var lastFoundRect: CGRect?  // Store the last found text position
    private var autoClick: Bool = false  // Whether to auto-click when found
    private var consecutiveMatchCount: Int = 0  // Track stable position
    private var lastMatchRect: CGRect? // Track if position is stable
    
    init(overlayWindow: OverlayWindow) {
        self.overlayWindow = overlayWindow
    }
    
    func startDetecting(searchText: String, exactMatch: Bool, caseSensitive: Bool, autoClick: Bool = false) {
        NSLog("\n========================================")
        NSLog("Starting detection")
        NSLog("Search text: '\(searchText)'")
        NSLog("Exact match: \(exactMatch)")
        NSLog("Case sensitive: \(caseSensitive)")
        NSLog("Auto-click: \(autoClick)")
        NSLog("========================================\n")
        
        self.searchText = caseSensitive ? searchText : searchText.lowercased()
        self.exactMatch = exactMatch
        self.caseSensitive = caseSensitive
        self.autoClick = autoClick
        self.consecutiveMatchCount = 0
        self.lastMatchRect = nil
        
        // Check accessibility permission if auto-click is enabled
        if autoClick && !AXIsProcessTrusted() {
            promptForAccessibilityPermission()
            return
        }
        
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
        lastFoundRect = nil
        consecutiveMatchCount = 0
        lastMatchRect = nil
    }
    
    func clickLastFoundText() {
        guard let rect = lastFoundRect else {
            NSLog("❌ No text location stored to click")
            return
        }
        
        NSLog("\n🎯 CLICK DEBUG INFO:")
        NSLog("   Found rect: x=\(Int(rect.minX)), y=\(Int(rect.minY)), w=\(Int(rect.width)), h=\(Int(rect.height))")
        
        // Check accessibility permission
        if !AXIsProcessTrusted() {
            NSLog("❌ No accessibility permission!")
            promptForAccessibilityPermission()
            return
        }
        NSLog("   ✅ Accessibility permission granted")
        
        // Get screen info
        guard let screen = NSScreen.main else { return }
        
        // Calculate click point (center of found text)
        let centerX = rect.midX
        let centerY = rect.midY
        
        // FLIP Y COORDINATE FOR CLICKING
        // The overlay uses top-left origin, but CGEvent uses bottom-left origin
        let clickY = screen.frame.height - centerY
        
        NSLog("   Target rect center: (\(Int(centerX)), \(Int(centerY)))")
        NSLog("   Flipped click point: (\(Int(centerX)), \(Int(clickY)))")
        NSLog("   Screen height: \(Int(screen.frame.height))")
        
        // Show red dot where we're actually clicking (with flipped Y)
        overlayWindow?.showClickPoint(at: CGPoint(x: centerX, y: centerY))  // Show at visual position
        
        // Get current mouse position for reference
        let currentMouse = NSEvent.mouseLocation
        NSLog("   Current mouse position: (\(Int(currentMouse.x)), \(Int(currentMouse.y)))")
        
        // Wait a bit so user can see the red dot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Click with FLIPPED Y coordinate
            self?.performClick(x: centerX, y: clickY)
        }
    }
    
    private func performClick(x: CGFloat, y: CGFloat) {
        NSLog("\n🖱️ PERFORMING CLICK:")
        NSLog("   Click coordinates: (\(Int(x)), \(Int(y)))")
        
        // Create event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            NSLog("   ❌ Failed to create event source")
            return
        }
        NSLog("   ✅ Event source created")
        
        // Move cursor to position first
        NSLog("   Moving cursor to position...")
        CGDisplayMoveCursorToPoint(CGMainDisplayID(), CGPoint(x: x, y: y))
        usleep(300_000) // 300ms delay to see cursor move
        
        // Verify cursor moved
        let newMousePos = NSEvent.mouseLocation
        NSLog("   Cursor now at: (\(Int(newMousePos.x)), \(Int(newMousePos.y)))")
        
        // Create mouse down event
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: CGPoint(x: x, y: y),
            mouseButton: .left
        ) else {
            NSLog("   ❌ Failed to create mouse down event")
            return
        }
        NSLog("   ✅ Mouse down event created")
        
        // Create mouse up event
        guard let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: CGPoint(x: x, y: y),
            mouseButton: .left
        ) else {
            NSLog("   ❌ Failed to create mouse up event")
            return
        }
        NSLog("   ✅ Mouse up event created")
        
        // Post the events
        NSLog("   Posting mouse down...")
        mouseDown.post(tap: .cghidEventTap)
        
        usleep(100_000) // 100ms between down and up
        
        NSLog("   Posting mouse up...")
        mouseUp.post(tap: .cghidEventTap)
        
        NSLog("   ✅ Click completed!")
        NSLog("================================================\n")
    }
    
    private func clickAtLocation(x: CGFloat, y: CGFloat) {
        // This is now just a wrapper that shows the click point and performs the click
        overlayWindow?.showClickPoint(at: CGPoint(x: x, y: y))
        
        // Wait for visual feedback then click
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.performClick(x: x, y: y)
        }
    }
    
    private func promptForAccessibilityPermission() {
        NSLog("⚠️ Accessibility permission required")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Navi needs accessibility permissions to click on screen elements. Please grant permission in System Preferences."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                // Open accessibility preferences
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
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
        lastFoundRect = nil
        
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
                
                // Keep the original working coordinate conversion
                let screenX = box.origin.x * screenFrame.width
                let screenWidth = box.width * screenFrame.width
                let screenHeight = box.height * screenFrame.height
                let screenY = box.origin.y * screenFrame.height
                
                let screenRect = CGRect(
                    x: screenX,
                    y: screenY,
                    width: screenWidth,
                    height: screenHeight
                )
                
                NSLog("   Vision box (normalized): x=\(String(format: "%.3f", box.origin.x)), y=\(String(format: "%.3f", box.origin.y)), w=\(String(format: "%.3f", box.width)), h=\(String(format: "%.3f", box.height))")
                NSLog("   Screen rect: x=\(Int(screenRect.minX)), y=\(Int(screenRect.minY)), w=\(Int(screenRect.width)), h=\(Int(screenRect.height))")
                
                // Store the found rectangle
                lastFoundRect = screenRect
                
                // Highlight the first match
                overlayWindow?.highlightText(at: screenRect)
                foundMatch = true
                
                // Auto-click if enabled - with page load detection
                if autoClick {
                    // Check if position is stable (element hasn't moved)
                    if let prevRect = lastMatchRect,
                       abs(prevRect.origin.x - screenRect.origin.x) < 5 &&
                       abs(prevRect.origin.y - screenRect.origin.y) < 5 {
                        // Position is stable, increment count
                        consecutiveMatchCount += 1
                        
                        // Click after 2 consecutive stable detections (4 seconds)
                        if consecutiveMatchCount >= 2 {
                            NSLog("✅ Element position stable, clicking...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                self?.clickLastFoundText()
                                self?.consecutiveMatchCount = 0 // Reset after clicking
                            }
                        } else {
                            NSLog("⏳ Waiting for stable position... (\(consecutiveMatchCount)/2)")
                        }
                    } else {
                        // Position changed, reset count
                        consecutiveMatchCount = 0
                        lastMatchRect = screenRect
                        NSLog("⏳ Element moved, resetting stability check...")
                    }
                }
                
                break  // Stop after first match
            }
        }
        
        if !foundMatch {
            NSLog("❌ Text '\(searchText)' not found on screen")
            consecutiveMatchCount = 0
            lastMatchRect = nil
        }
    }
}

// Note: Main entry point is in main.swift
