import SwiftUI

@main
struct PressureRamMonitorApp: App {
    @StateObject var memoryMonitor = MemoryMonitor()
    
    var body: some Scene {
        Settings {}
    }
}
