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
    
    // Section 1: Click Button/Link
    private var clickSearchField: NSTextField!
    private var clickExactMatchCheckbox: NSButton!
    private var clickCaseSensitiveCheckbox: NSButton!
    private var clickAutoCheckbox: NSButton!
    private var startClickDetectionButton: NSButton!
    
    // Section 2: Type in Field
    private var typeMessageField: NSTextField!
    private var typeAutoCheckbox: NSButton!
    private var startTypeDetectionButton: NSButton!
    
    // Section 3: Text Selection Monitor (NEW)
    private var selectionMonitorButton: NSButton!
    private var selectionStatusLabel: NSTextField!
    private var isAutoMonitoring = false
    
    // Shared controls
    private var stopButton: NSButton!
    private var statusLabel: NSTextField!
    private var urlField: NSTextField!
    private var openBrowserButton: NSButton!
    
    init(textDetector: TextDetector) {
        self.textDetector = textDetector
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 620),
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
            frame: NSRect(x: 20, y: 570, width: 410, height: 30),
            fontSize: 18,
            weight: .bold
        )
        contentView.addSubview(titleLabel)
        
        // ==================== SECTION 1: CLICK BUTTON/LINK ====================
        
        // Section 1 Header
        let clickSectionLabel = createLabel(
            text: "🖱️ Click Button or Link",
            frame: NSRect(x: 20, y: 530, width: 410, height: 25),
            fontSize: 14,
            weight: .semibold
        )
        clickSectionLabel.alignment = .left
        clickSectionLabel.textColor = .systemBlue
        contentView.addSubview(clickSectionLabel)
        
        // Click Search Field
        clickSearchField = NSTextField(frame: NSRect(x: 20, y: 490, width: 410, height: 30))
        clickSearchField.placeholderString = "Enter button/link text to click (e.g., 'Submit', 'Sign In')"
        contentView.addSubview(clickSearchField)
        
        // Click Options
        clickExactMatchCheckbox = NSButton(checkboxWithTitle: "Exact match", target: nil, action: nil)
        clickExactMatchCheckbox.frame = NSRect(x: 20, y: 460, width: 100, height: 20)
        clickExactMatchCheckbox.state = .off
        contentView.addSubview(clickExactMatchCheckbox)
        
        clickCaseSensitiveCheckbox = NSButton(checkboxWithTitle: "Case sensitive", target: nil, action: nil)
        clickCaseSensitiveCheckbox.frame = NSRect(x: 130, y: 460, width: 110, height: 20)
        clickCaseSensitiveCheckbox.state = .off
        contentView.addSubview(clickCaseSensitiveCheckbox)
        
        clickAutoCheckbox = NSButton(checkboxWithTitle: "Auto-click", target: nil, action: nil)
        clickAutoCheckbox.frame = NSRect(x: 250, y: 460, width: 90, height: 20)
        clickAutoCheckbox.state = .off
        clickAutoCheckbox.toolTip = "Automatically click when found"
        contentView.addSubview(clickAutoCheckbox)
        
        // Start Click Detection Button
        startClickDetectionButton = NSButton(frame: NSRect(x: 20, y: 420, width: 410, height: 32))
        startClickDetectionButton.title = "Start Detecting Button/Link"
        startClickDetectionButton.bezelStyle = .rounded
        startClickDetectionButton.target = self
        startClickDetectionButton.action = #selector(startClickDetection)
        contentView.addSubview(startClickDetectionButton)
        
        // Divider
        let divider1 = NSBox(frame: NSRect(x: 20, y: 400, width: 410, height: 1))
        divider1.boxType = .separator
        contentView.addSubview(divider1)
        
        // ==================== SECTION 2: TYPE IN TEXT FIELD ====================
        
        // Section 2 Header
        let typeSectionLabel = createLabel(
            text: "⌨️ Auto-Detect & Type in Text Fields",
            frame: NSRect(x: 20, y: 365, width: 410, height: 25),
            fontSize: 14,
            weight: .semibold
        )
        typeSectionLabel.alignment = .left
        typeSectionLabel.textColor = .systemGreen
        contentView.addSubview(typeSectionLabel)
        
        // Instructions Label
        let instructionsLabel = createLabel(
            text: "Automatically finds input fields on screen",
            frame: NSRect(x: 20, y: 340, width: 410, height: 20),
            fontSize: 11,
            weight: .regular
        )
        instructionsLabel.alignment = .left
        instructionsLabel.textColor = .secondaryLabelColor
        contentView.addSubview(instructionsLabel)
        
        // Type Message Field
        typeMessageField = NSTextField(frame: NSRect(x: 20, y: 300, width: 410, height: 30))
        typeMessageField.placeholderString = "Enter text to type in the detected field"
        contentView.addSubview(typeMessageField)
        
        // Type Options
        typeAutoCheckbox = NSButton(checkboxWithTitle: "Auto-type when field is found", target: nil, action: nil)
        typeAutoCheckbox.frame = NSRect(x: 20, y: 270, width: 220, height: 20)
        typeAutoCheckbox.state = .on
        typeAutoCheckbox.toolTip = "Automatically click field and type message"
        contentView.addSubview(typeAutoCheckbox)
        
        // Start Type Detection Button
        startTypeDetectionButton = NSButton(frame: NSRect(x: 20, y: 230, width: 410, height: 32))
        startTypeDetectionButton.title = "Find Text Field & Type"
        startTypeDetectionButton.bezelStyle = .rounded
        startTypeDetectionButton.target = self
        startTypeDetectionButton.action = #selector(startTypeDetection)
        contentView.addSubview(startTypeDetectionButton)
        
        // Divider
        let divider2 = NSBox(frame: NSRect(x: 20, y: 210, width: 410, height: 1))
        divider2.boxType = .separator
        contentView.addSubview(divider2)
        
        // ==================== SECTION 3: TEXT SELECTION MONITOR ====================
        
        // Section 3 Header
        let selectionSectionLabel = createLabel(
            text: "✨ Text Selection Monitor",
            frame: NSRect(x: 20, y: 175, width: 410, height: 25),
            fontSize: 14,
            weight: .semibold
        )
        selectionSectionLabel.alignment = .left
        selectionSectionLabel.textColor = .systemPurple
        contentView.addSubview(selectionSectionLabel)
        
        // Selection Status Label
        selectionStatusLabel = createLabel(
            text: "Auto-detect is OFF",
            frame: NSRect(x: 20, y: 145, width: 410, height: 20),
            fontSize: 11,
            weight: .regular
        )
        selectionStatusLabel.alignment = .left
        selectionStatusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(selectionStatusLabel)
        
        // Auto Monitor Toggle Button
        selectionMonitorButton = NSButton(frame: NSRect(x: 20, y: 105, width: 410, height: 32))
        selectionMonitorButton.title = "▶️ Start Auto-Detect Selections"
        selectionMonitorButton.bezelStyle = .rounded
        selectionMonitorButton.target = self
        selectionMonitorButton.action = #selector(toggleAutoMonitor)
        contentView.addSubview(selectionMonitorButton)
        
        // Divider
        let divider3 = NSBox(frame: NSRect(x: 20, y: 85, width: 410, height: 1))
        divider3.boxType = .separator
        contentView.addSubview(divider3)
        
        // ==================== SHARED CONTROLS ====================
        
        // Stop Button (works for both modes)
        stopButton = NSButton(frame: NSRect(x: 20, y: 45, width: 200, height: 32))
        stopButton.title = "🛑 Stop Detection"
        stopButton.bezelStyle = .rounded
        stopButton.target = self
        stopButton.action = #selector(stopDetection)
        stopButton.isEnabled = false
        contentView.addSubview(stopButton)
        
        // Open Browser Button
        openBrowserButton = NSButton(frame: NSRect(x: 230, y: 45, width: 200, height: 32))
        openBrowserButton.title = "🌐 Open Browser"
        openBrowserButton.bezelStyle = .rounded
        openBrowserButton.target = self
        openBrowserButton.action = #selector(openBrowser)
        contentView.addSubview(openBrowserButton)
        
        // Status Label
        statusLabel = createLabel(
            text: "Ready",
            frame: NSRect(x: 20, y: 10, width: 410, height: 25),
            fontSize: 11,
            weight: .regular
        )
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
    
    @objc private func toggleAutoMonitor() {
        isAutoMonitoring = !isAutoMonitoring
        
        if isAutoMonitoring {
            NSLog("🟢 Starting auto-monitoring...")
            textDetector?.startSelectionMonitoring()
            
            selectionMonitorButton.title = "⏸ Stop Auto-Detect"
            selectionStatusLabel.stringValue = "AUTO-DETECT ON - Just select text!"
            selectionStatusLabel.textColor = .systemGreen
            
            statusLabel.stringValue = "✨ Auto-detecting text selections"
            statusLabel.textColor = .systemPurple
        } else {
            NSLog("🔴 Stopping auto-monitoring...")
            textDetector?.stopSelectionMonitoring()
            
            selectionMonitorButton.title = "▶️ Start Auto-Detect Selections"
            selectionStatusLabel.stringValue = "Auto-detect is OFF"
            selectionStatusLabel.textColor = .secondaryLabelColor
            
            statusLabel.stringValue = "Ready"
            statusLabel.textColor = .secondaryLabelColor
        }
    }
    
    func updateSelectionStatus(_ text: String) {
        if isAutoMonitoring {
            selectionStatusLabel.stringValue = "AUTO-CAPTURED: \(text.prefix(50))..."
            selectionStatusLabel.textColor = .systemPurple
            
            // Reset after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.isAutoMonitoring == true {
                    self?.selectionStatusLabel.stringValue = "AUTO-DETECT ON - Just select text!"
                    self?.selectionStatusLabel.textColor = .systemGreen
                }
            }
        }
    }
    
    @objc private func startClickDetection() {
        let searchText = clickSearchField.stringValue
        guard !searchText.isEmpty else {
            statusLabel.stringValue = "Please enter button/link text to search for"
            statusLabel.textColor = .systemRed
            return
        }
        
        let exactMatch = clickExactMatchCheckbox.state == .on
        let caseSensitive = clickCaseSensitiveCheckbox.state == .on
        let autoClick = clickAutoCheckbox.state == .on
        
        textDetector?.startDetecting(
            searchText: searchText,
            exactMatch: exactMatch,
            caseSensitive: caseSensitive,
            autoClick: autoClick,
            autoType: false,
            typeMessage: ""
        )
        
        statusLabel.stringValue = "🖱️ Looking for: \"\(searchText)\"\(autoClick ? " (Auto-click)" : "")"
        statusLabel.textColor = .systemBlue
        
        setClickDetectionControlsEnabled(false)
        setTypeDetectionControlsEnabled(true)
        stopButton.isEnabled = true
    }
    
    @objc private func startTypeDetection() {
        let message = typeMessageField.stringValue
        
        guard !message.isEmpty else {
            statusLabel.stringValue = "Please enter text to type"
            statusLabel.textColor = .systemRed
            return
        }
        
        let autoType = typeAutoCheckbox.state == .on
        
        textDetector?.startDetectingTextField(
            typeMessage: message,
            autoType: autoType
        )
        
        statusLabel.stringValue = "⌨️ Looking for text input field to type: \"\(message)\""
        statusLabel.textColor = .systemGreen
        
        setTypeDetectionControlsEnabled(false)
        setClickDetectionControlsEnabled(true)
        stopButton.isEnabled = true
    }
    
    @objc private func stopDetection() {
        textDetector?.stopDetecting()
        
        statusLabel.stringValue = "Detection stopped"
        statusLabel.textColor = .secondaryLabelColor
        
        setClickDetectionControlsEnabled(true)
        setTypeDetectionControlsEnabled(true)
        stopButton.isEnabled = false
    }
    
    private func setClickDetectionControlsEnabled(_ enabled: Bool) {
        clickSearchField.isEnabled = enabled
        clickExactMatchCheckbox.isEnabled = enabled
        clickCaseSensitiveCheckbox.isEnabled = enabled
        clickAutoCheckbox.isEnabled = enabled
        startClickDetectionButton.isEnabled = enabled
    }
    
    private func setTypeDetectionControlsEnabled(_ enabled: Bool) {
        typeMessageField.isEnabled = enabled
        typeAutoCheckbox.isEnabled = enabled
        startTypeDetectionButton.isEnabled = enabled
    }
    
    @objc private func openBrowser() {
        var urlString = urlField.stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if urlString.isEmpty {
            urlString = "https://google.com"
        }
        
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString) else {
            statusLabel.stringValue = "Invalid URL"
            statusLabel.textColor = .systemRed
            return
        }
        
        NSLog("🌐 Opening browser with URL: \(urlString)")
        NSWorkspace.shared.open(url)
        
        statusLabel.stringValue = "Browser opened: \(urlString)"
        statusLabel.textColor = .systemGreen
        
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
    
    func showCapturedText(_ text: String) {
        (self.contentView as? OverlayView)?.showCapturedText(text)
    }
}

// MARK: - Overlay View (with captured text display)
class OverlayView: NSView {
    private var targetRect: CGRect?
    private var clickPoint: CGPoint?
    private var capturedText: String?
    private var textDisplayTimer: Timer?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw captured text display
        if let text = capturedText {
            drawCapturedTextOverlay(text)
        }
        
        // Draw text highlight if present
        if let rect = targetRect {
            drawTextHighlight(rect)
        }
        
        // Draw click point indicator if present
        if let point = clickPoint {
            drawClickIndicator(point)
        }
    }
    
    private func drawCapturedTextOverlay(_ text: String) {
        let maxWidth: CGFloat = 600
        let x = (bounds.width - maxWidth) / 2
        let y = bounds.height - 150
        
        let bgRect = NSRect(x: x, y: y, width: maxWidth, height: 100)
        
        // Background
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 10, yRadius: 10)
        NSColor.black.withAlphaComponent(0.9).setFill()
        bgPath.fill()
        
        // Border
        NSColor.systemPurple.setStroke()
        bgPath.lineWidth = 2.0
        bgPath.stroke()
        
        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.systemPurple
        ]
        let title = "✨ Captured Text:"
        title.draw(at: NSPoint(x: x + 20, y: y + 70), withAttributes: titleAttrs)
        
        // Text content
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white
        ]
        
        let displayText = String(text.prefix(200))
        let textRect = NSRect(x: x + 20, y: y + 20, width: maxWidth - 40, height: 40)
        displayText.draw(in: textRect, withAttributes: textAttrs)
    }
    
    private func drawTextHighlight(_ rect: CGRect) {
        let expandedRect = rect.insetBy(dx: -8, dy: -6)
        let cornerRadius: CGFloat = expandedRect.height / 2.5
        let roundedPath = NSBezierPath(roundedRect: expandedRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        let highlightColor = NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        
        highlightColor.withAlphaComponent(0.1).setFill()
        roundedPath.fill()
        
        highlightColor.setStroke()
        roundedPath.lineWidth = 2.0
        roundedPath.stroke()
        
        // Dot indicator
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
    
    private func drawClickIndicator(_ point: CGPoint) {
        let clickRadius: CGFloat = 20
        
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
        
        NSColor.red.withAlphaComponent(0.3).setFill()
        outerCircle.fill()
    }
    
    func highlightText(at rect: CGRect) {
        targetRect = rect
        self.needsDisplay = true
    }
    
    func showClickPoint(at point: CGPoint) {
        clickPoint = point
        self.needsDisplay = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.clickPoint = nil
            self?.needsDisplay = true
        }
    }
    
    func clearOverlay() {
        targetRect = nil
        clickPoint = nil
        capturedText = nil
        textDisplayTimer?.invalidate()
        self.needsDisplay = true
    }
    
    func showCapturedText(_ text: String) {
        capturedText = text
        self.needsDisplay = true
        
        // Hide after 5 seconds
        textDisplayTimer?.invalidate()
        textDisplayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.capturedText = nil
            self?.needsDisplay = true
        }
    }
}

// MARK: - Text Detector (Integrated with all features)
class TextDetector {
    private weak var overlayWindow: OverlayWindow?
    private var timer: Timer?
    private var searchText: String = ""
    private var exactMatch: Bool = false
    private var caseSensitive: Bool = false
    private var lastFoundRect: CGRect?
    private var autoClick: Bool = false
    private var autoType: Bool = false
    private var typeMessage: String = ""
    private var consecutiveMatchCount: Int = 0
    private var lastMatchRect: CGRect?
    private var isDetectingTextField: Bool = false
    
    // Selection monitoring additions
    private var selectionMonitorTimer: Timer?
    private var mouseEventMonitor: Any?
    private var lastClipboardContent: String = ""
    private var isMonitoringSelection: Bool = false
    private var isProcessingSelection: Bool = false
    
    init(overlayWindow: OverlayWindow) {
        self.overlayWindow = overlayWindow
        
        // Initialize clipboard content
        if let content = NSPasteboard.general.string(forType: .string) {
            lastClipboardContent = content
        }
    }
    
    // MARK: - Selection Monitoring (NEW)
    
    func startSelectionMonitoring() {
        guard !isMonitoringSelection else { return }
        
        NSLog("🔍 Starting automatic selection detection...")
        
        if !AXIsProcessTrusted() {
            NSLog("⚠️ Need accessibility permission for auto-detection")
            promptForAccessibilityPermission()
            return
        }
        
        isMonitoringSelection = true
        
        // Save current clipboard
        if let content = NSPasteboard.general.string(forType: .string) {
            lastClipboardContent = content
        }
        
        // Monitor mouse events
        setupMouseEventMonitor()
        
        NSLog("✅ Auto-detection active - Just select text with your mouse!")
    }
    
    func stopSelectionMonitoring() {
        NSLog("⏹ Stopping auto-detection")
        isMonitoringSelection = false
        
        selectionMonitorTimer?.invalidate()
        selectionMonitorTimer = nil
        
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
    }
    
    private func setupMouseEventMonitor() {
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self, self.isMonitoringSelection else { return }
            
            NSLog("🖱️ Mouse released - checking for selection...")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkForTextSelection()
            }
        }
        
        NSLog("📌 Mouse event monitor installed")
    }
    
    private func checkForTextSelection() {
        guard !isProcessingSelection else { return }
        isProcessingSelection = true
        
        let pasteboard = NSPasteboard.general
        let savedContent = pasteboard.string(forType: .string)
        let savedChangeCount = pasteboard.changeCount
        
        NSLog("🔍 Attempting to capture selection...")
        
        // Simulate Cmd+C
        if let source = CGEventSource(stateID: .hidSystemState) {
            let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
            cmdCDown?.flags = .maskCommand
            let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
            cmdCUp?.flags = .maskCommand
            
            cmdCDown?.post(tap: .cghidEventTap)
            usleep(20_000)
            cmdCUp?.post(tap: .cghidEventTap)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                
                let newChangeCount = pasteboard.changeCount
                
                if newChangeCount != savedChangeCount {
                    if let newText = pasteboard.string(forType: .string),
                       !newText.isEmpty,
                       newText != self.lastClipboardContent {
                        
                        NSLog("✨ AUTO-CAPTURED: '\(String(newText.prefix(100)))'")
                        
                        self.overlayWindow?.showCapturedText(newText)
                        
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.controlWindow?.updateSelectionStatus(newText)
                        }
                        
                        self.lastClipboardContent = newText
                        
                        // Restore old clipboard
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if let saved = savedContent, saved != newText {
                                pasteboard.clearContents()
                                pasteboard.setString(saved, forType: .string)
                                NSLog("📋 Restored original clipboard")
                            }
                        }
                    }
                }
                
                self.isProcessingSelection = false
            }
        }
    }
    
    // MARK: - Original Detection Methods
    
    func startDetecting(searchText: String, exactMatch: Bool, caseSensitive: Bool, autoClick: Bool = false, autoType: Bool = false, typeMessage: String = "") {
        NSLog("\n========================================")
        NSLog("Starting detection")
        NSLog("Search text: '\(searchText)'")
        NSLog("========================================\n")
        
        self.searchText = caseSensitive ? searchText : searchText.lowercased()
        self.exactMatch = exactMatch
        self.caseSensitive = caseSensitive
        self.autoClick = autoClick
        self.autoType = autoType
        self.typeMessage = typeMessage
        self.consecutiveMatchCount = 0
        self.lastMatchRect = nil
        self.isDetectingTextField = false
        
        if (autoClick || autoType) && !AXIsProcessTrusted() {
            promptForAccessibilityPermission()
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                self?.detectText()
            }
            self?.detectText()
        }
    }
    
    func startDetectingTextField(typeMessage: String, autoType: Bool) {
        NSLog("\n========================================")
        NSLog("Starting text field detection")
        NSLog("========================================\n")
        
        self.typeMessage = typeMessage
        self.autoType = autoType
        self.consecutiveMatchCount = 0
        self.lastMatchRect = nil
        self.isDetectingTextField = true
        
        if !AXIsProcessTrusted() {
            promptForAccessibilityPermission()
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                self?.detectTextFields()
            }
            self?.detectTextFields()
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
        isDetectingTextField = false
    }
    
    // [All the original methods remain the same: detectText, processResults, detectTextFields, etc.]
    // Including them here for completeness...
    
    private func detectText() {
        NSLog("\n🔍 Scanning screen for: '\(searchText)'")
        
        guard let screen = NSScreen.main else { return }
        
        let displayID = CGMainDisplayID()
        guard let screenshot = CGDisplayCreateImage(displayID) else {
            NSLog("ERROR: Cannot capture screen")
            return
        }
        
        let imageWidth = CGFloat(screenshot.width)
        let imageHeight = CGFloat(screenshot.height)
        
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
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.0
        
        let handler = VNImageRequestHandler(cgImage: screenshot, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            NSLog("ERROR: \(error.localizedDescription)")
        }
    }
    
    private func processResults(_ observations: [VNRecognizedTextObservation], imageSize: CGSize) {
        overlayWindow?.clearOverlay()
        lastFoundRect = nil
        
        var foundMatch = false
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        for (index, observation) in observations.enumerated() {
            guard let recognizedText = observation.topCandidates(1).first?.string else { continue }
            
            let textToCompare = caseSensitive ? recognizedText : recognizedText.lowercased()
            
            let isMatch: Bool
            if exactMatch {
                isMatch = textToCompare == searchText
            } else {
                isMatch = textToCompare.contains(searchText)
            }
            
            if isMatch {
                NSLog("\n✅ FOUND MATCH!")
                
                let box = observation.boundingBox
                
                let screenRect = CGRect(
                    x: box.origin.x * screenFrame.width,
                    y: box.origin.y * screenFrame.height,
                    width: box.width * screenFrame.width,
                    height: box.height * screenFrame.height
                )
                
                lastFoundRect = screenRect
                overlayWindow?.highlightText(at: screenRect)
                foundMatch = true
                
                if autoClick {
                    if let prevRect = lastMatchRect,
                       abs(prevRect.origin.x - screenRect.origin.x) < 5 &&
                       abs(prevRect.origin.y - screenRect.origin.y) < 5 {
                        
                        consecutiveMatchCount += 1
                        
                        if consecutiveMatchCount >= 2 {
                            NSLog("✅ Element position stable, clicking...")
                            
                            timer?.invalidate()
                            timer = nil
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                                self?.clickLastFoundText()
                                self?.consecutiveMatchCount = 0
                            }
                        }
                    } else {
                        consecutiveMatchCount = 0
                        lastMatchRect = screenRect
                    }
                }
                
                break
            }
        }
        
        if !foundMatch {
            NSLog("❌ Text '\(searchText)' not found on screen")
            consecutiveMatchCount = 0
            lastMatchRect = nil
        }
    }
    
    func clickLastFoundText() {
        guard let rect = lastFoundRect else { return }
        
        if !AXIsProcessTrusted() {
            promptForAccessibilityPermission()
            return
        }
        
        guard let screen = NSScreen.main else { return }
        
        let centerX = rect.midX
        let centerY = rect.midY
        let clickY = screen.frame.height - centerY
        
        overlayWindow?.showClickPoint(at: CGPoint(x: centerX, y: centerY))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performClick(x: centerX, y: clickY)
        }
    }
    
    private func performClick(x: CGFloat, y: CGFloat) {
        NSLog("🖱️ Performing click at (\(Int(x)), \(Int(y)))")
        
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        CGDisplayMoveCursorToPoint(CGMainDisplayID(), CGPoint(x: x, y: y))
        usleep(300_000)
        
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: CGPoint(x: x, y: y),
            mouseButton: .left
        ),
        let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: CGPoint(x: x, y: y),
            mouseButton: .left
        ) else { return }
        
        mouseDown.post(tap: .cghidEventTap)
        usleep(100_000)
        mouseUp.post(tap: .cghidEventTap)
        
        NSLog("✅ Click completed!")
    }
    
    private func detectTextFields() {
        NSLog("\n🔍 Scanning for text input fields...")
        
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedApp: CFTypeRef?
        AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        guard let app = focusedApp else {
            NSLog("No focused application found")
            return
        }
        
        if let textField = findFirstTextField(in: app as! AXUIElement) {
            NSLog("✅ Found text field")
            
            if let fieldRect = getTextFieldRect(textField) {
                checkStabilityAndClick(fieldRect, textField: textField)
            }
        } else {
            NSLog("No text field found")
            consecutiveMatchCount = 0
            lastMatchRect = nil
        }
    }
    
    private func findFirstTextField(in element: AXUIElement) -> AXUIElement? {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            if roleString == kAXTextFieldRole ||
               roleString == kAXTextAreaRole ||
               roleString == kAXComboBoxRole ||
               roleString == "AXSearchField" {
                return element
            }
        }
        
        var children: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childArray = children as? [AXUIElement] {
            for child in childArray {
                if let found = findFirstTextField(in: child) {
                    return found
                }
            }
        }
        
        return nil
    }
    
    private func getTextFieldRect(_ element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        
        if let posValue = position, let sizeValue = size {
            var point = CGPoint.zero
            var dimensions = CGSize.zero
            
            AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &dimensions)
            
            return CGRect(origin: point, size: dimensions)
        }
        
        return nil
    }
    
    private func checkStabilityAndClick(_ rect: CGRect, textField: AXUIElement?) {
        if let prevRect = lastMatchRect,
           abs(prevRect.origin.x - rect.origin.x) < 5 &&
           abs(prevRect.origin.y - rect.origin.y) < 5 {
            
            consecutiveMatchCount += 1
            
            if consecutiveMatchCount >= 2 {
                NSLog("✅ Text field position stable, clicking...")
                
                lastFoundRect = rect
                timer?.invalidate()
                timer = nil
                
                let centerX = rect.midX
                let centerY = rect.midY
                
                guard let screen = NSScreen.main else { return }
                let displayY = screen.frame.height - centerY
                
                overlayWindow?.highlightText(at: CGRect(
                    x: rect.origin.x,
                    y: screen.frame.height - rect.origin.y - rect.height,
                    width: rect.width,
                    height: rect.height
                ))
                overlayWindow?.showClickPoint(at: CGPoint(x: centerX, y: displayY))
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    if let textField = textField {
                        AXUIElementSetAttributeValue(textField, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                    }
                    
                    self?.performClick(x: centerX, y: centerY)
                    
                    if self?.autoType == true, let message = self?.typeMessage, !message.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self?.typeText(message)
                            self?.consecutiveMatchCount = 0
                        }
                    } else {
                        self?.consecutiveMatchCount = 0
                    }
                }
            }
        } else {
            consecutiveMatchCount = 0
            lastMatchRect = rect
            
            guard let screen = NSScreen.main else { return }
            overlayWindow?.highlightText(at: CGRect(
                x: rect.origin.x,
                y: screen.frame.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            ))
        }
    }
    
    private func typeText(_ text: String) {
        NSLog("⌨️ Typing text: '\(text)'")
        
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        for character in text {
            let chars = Array(String(character).utf16)
            
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }
            
            chars.withUnsafeBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: buffer.baseAddress)
                keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: buffer.baseAddress)
            }
            
            keyDown.post(tap: .cghidEventTap)
            usleep(10_000)
            keyUp.post(tap: .cghidEventTap)
            usleep(30_000)
        }
        
        NSLog("✅ Finished typing text")
    }
    
    private func promptForAccessibilityPermission() {
        NSLog("⚠️ Accessibility permission required")
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Navi needs accessibility permissions to interact with screen elements."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

// Note: Main entry point is in main.swift
