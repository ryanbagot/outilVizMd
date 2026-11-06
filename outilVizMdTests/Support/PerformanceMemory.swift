import Darwin
import Foundation

enum PerformanceMemory {
    static func sample() -> [String: UInt64] {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return [:] }
        return ["resident_bytes_app_only": UInt64(info.resident_size), "peak_resident_bytes_app_only": UInt64(info.resident_size_max)]
    }
}
