import Foundation
import AppKit
import Darwin

class MemoryMonitor: ObservableObject {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var lastPressure: String?
    
    init() {
        DispatchQueue.main.async {
            self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            self.createMenu()
            self.startMonitoring()
        }
    }
    
    func createMenu() {
        menu = NSMenu()
        
        let statusMenu = NSMenuItem(title: "Status: Loading...", action: nil, keyEquivalent: "")
        statusMenu.target = self
        menu.addItem(statusMenu)
        
        let quitItem = NSMenuItem(title: "STOP Application", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func quit() {
        NSStatusBar.system.removeStatusItem(statusItem)
        NSApp.terminate(nil)
    }
    
    func startMonitoring() {
        Timer.scheduledTimer(timeInterval: 7.0, target: self, selector: #selector(updateMemoryUsage), userInfo: nil, repeats: true)
        updateMemoryUsage()
    }
    
    @objc func updateMemoryUsage() {
        let currentPressure = getMemoryPressure()
        
        if let statusMenu = self.menu.items.first(where: { $0.title.contains("Status") }) {
            statusMenu.title = "Status: \(currentPressure.capitalized)"
        }
        
        if currentPressure != lastPressure {
            DispatchQueue.main.async {
                self.statusItem.button?.image = self.getImageForPressure(currentPressure)
            }
            lastPressure = currentPressure
        }
    }
    
    func getImageForPressure(_ pressure: String) -> NSImage? {
        switch pressure {
            case "normal":
                return NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Normal Memory")
            case "caution":
                return NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Caution Memory")
            case "severe":
                return NSImage(systemSymbolName: "xmark.octagon", accessibilityDescription: "Severe Memory")
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
