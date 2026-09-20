import Foundation

enum HeartRateMeasurementParser {
    enum ParseError: Error, Equatable {
        case missingFlags
        case missingHeartRateValue
    }

    static func parse(_ data: Data) throws -> Int {
        guard let flags = data.first else {
            throw ParseError.missingFlags
        }

        let usesUInt16 = flags & 0x01 != 0

        if usesUInt16 {
            guard data.count >= 3 else {
                throw ParseError.missingHeartRateValue
            }

            return Int(data[1]) | (Int(data[2]) << 8)
        }

        guard data.count >= 2 else {
            throw ParseError.missingHeartRateValue
        }

        return Int(data[1])
    }
}
