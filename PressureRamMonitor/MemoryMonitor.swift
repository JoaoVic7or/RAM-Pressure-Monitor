import Foundation
import AppKit
import Darwin

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}

class MemoryMonitor: NSObject, ObservableObject, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var lastPressure: String?
    
    required override init() {
        super.init()
        DispatchQueue.main.async {
            self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            self.createMenu()
            self.startMonitoring()
        }
    }
    
    func createMenu() {
        menu = NSMenu()
        menu.delegate = self

        let statusView = createCustomMenuItemView(text: "Status: Loading...")
        let statusMenu = NSMenuItem()
        statusMenu.view = statusView
        menu.addItem(statusMenu)

        let swapView = createCustomMenuItemView(text: "Swap: Loading...")
        let swapMemoryItem = NSMenuItem()
        swapMemoryItem.view = swapView
        menu.addItem(swapMemoryItem)

        statusItem.menu = menu
    }
    
    func createCustomMenuItemView(text: String) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 130, height: 22))

        let label = NSTextField(labelWithString: text)
        label.textColor = .labelColor // Cor dinâmica para se ajustar ao tema do sistema
        label.font = NSFont.systemFont(ofSize: 12)
        label.alignment = .left
        label.isBordered = false
        label.drawsBackground = false
        
        label.frame = NSRect(x: 10, y: -3, width: 110, height: 22)

        view.addSubview(label)
        return view
    }

    @objc func quit() {
        NSStatusBar.system.removeStatusItem(statusItem)
        NSApp.terminate(nil)
    }
    
    func startMonitoring() {
        Timer.scheduledTimer(timeInterval: 7.0, target: self, selector: #selector(updateStatus), userInfo: nil, repeats: true)
        updateStatus()
    }
    
    @objc func updateStatus() {
        let currentPressure = getMemoryPressure()

        if currentPressure != lastPressure {
            DispatchQueue.main.async {
                self.statusItem.button?.image = self.getImageForPressure(currentPressure)
                if let statusMenu = self.menu.items.first, let statusView = statusMenu.view {
                    if let label = statusView.subviews.first as? NSTextField {
                        label.stringValue = "Status: \(currentPressure.capitalized)"
                    }
                }
            }
            lastPressure = currentPressure
        }

        updateMemoryMenuItems()
    }


    func updateMemoryMenuItems() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: vmStats) / MemoryLayout<Int32>.size)
        let hostPort = mach_host_self()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return
        }
        
        let swapMemory = getSwapMemory()

        DispatchQueue.main.async {
            if let swapMemoryItem = self.menu.items.last, let swapView = swapMemoryItem.view {
                if let label = swapView.subviews.first as? NSTextField {
                    label.stringValue = "Swap: \(self.formatMemoryMB(swapMemory.used))"
                }
            }
        }
    }

    func formatMemory(_ bytes: UInt64) -> String {
        let gigabytes = Double(bytes) / (1024 * 1024 * 1024)
        return String(format: "%.2f GB", gigabytes)
    }
    
    func formatMemoryMB(_ bytes: UInt64) -> String {
        let megabytes = Double(bytes) / (1024 * 1024)
        return String(format: "%.2f MB", megabytes)
    }
    
    func getSwapMemory() -> (used: UInt64, total: UInt64) {
        var xswUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size

        let result = sysctlbyname("vm.swapusage", &xswUsage, &size, nil, 0)
        guard result == 0 else {
            print("Error fetching swap memory")
            return (0, 0)
        }

        let usedSwap = xswUsage.xsu_used
        let totalSwap = xswUsage.xsu_total

        return (used: usedSwap, total: totalSwap)
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        updateMemoryMenuItems()
    }
    
    func getImageForPressure(_ pressure: String) -> NSImage? {
        switch pressure {
            case "normal":
                return NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Normal Memory")
            case "caution":
                var image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Caution Memory")
                image = image?.withSymbolConfiguration(.init(pointSize: 12, weight: .regular))?.tinted(with: .white)
                let text = "CAUTION"
                
                let textSize = text.size(withAttributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.white
                ])
            
                let size = CGSize(width: (image?.size.width ?? 50) + textSize.width + 5,
                                  height: max(image?.size.height ?? 50, textSize.height))
                
                let imageWithText = NSImage(size: size)
                
                imageWithText.lockFocus()
                
                image?.draw(at: NSPoint(x: 0, y: (size.height - (image?.size.height ?? 0)) / 2),
                            from: NSRect(origin: .zero, size: image?.size ?? .zero),
                            operation: .sourceOver, fraction: 1.0)
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.white,
                    .paragraphStyle: paragraphStyle
                ]
                
                let textRect = NSRect(x: (image?.size.width ?? 50) + 5, y: (size.height - textSize.height) / 2,
                                      width: textSize.width, height: textSize.height)
                text.draw(in: textRect, withAttributes: attributes)
                
                imageWithText.unlockFocus()
            
                return imageWithText;
                
            case "severe":
                let image = NSImage(systemSymbolName: "xmark.octagon", accessibilityDescription: "Severe Memory")
                let text = "SEVERE"
                
                let textSize = text.size(withAttributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.black
                ])
                
                let size = CGSize(width: (image?.size.width ?? 50) + textSize.width + 5,
                                  height: max(image?.size.height ?? 50, textSize.height))
                
                let imageWithText = NSImage(size: size)
                
                imageWithText.lockFocus()
                
                image?.draw(at: NSPoint(x: 0, y: (size.height - (image?.size.height ?? 0)) / 2),
                            from: NSRect(origin: .zero, size: image?.size ?? .zero),
                            operation: .sourceOver, fraction: 1.0)
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: paragraphStyle
                ]
                
                let textRect = NSRect(x: (image?.size.width ?? 50) + 5, y: (size.height - textSize.height) / 2,
                                      width: textSize.width, height: textSize.height)
                text.draw(in: textRect, withAttributes: attributes)
                
                imageWithText.unlockFocus()
                
                return imageWithText
            default:
                return nil
        }
    }
    
    func getMemoryPressure() -> String {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: vmStats) / MemoryLayout<Int32>.size)
        let hostPort = mach_host_self()
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return ""
        }
        
        var intSize: size_t = MemoryLayout<uint>.size
        var pressure: Int = 0
        
        sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &intSize, nil, 0)
        
        switch pressure {
            case 1:
                return "normal"
            case 2:
                return "caution"
            case 3:
                return "severe"
            default:
                return ""
        }
    }
}
