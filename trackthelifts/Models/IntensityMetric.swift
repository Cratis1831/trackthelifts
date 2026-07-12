import Foundation

enum IntensityMetric: String, Codable, CaseIterable, Identifiable {
    case rpe
    case rir

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }

    var values: [Double] {
        switch self {
        case .rpe:
            return stride(from: 1.0, through: 10.0, by: 0.5).map { $0 }
        case .rir:
            return (0...10).map(Double.init)
        }
    }

    func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
