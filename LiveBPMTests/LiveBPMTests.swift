import Foundation
import Testing

struct HeartRateMeasurementParserTests {
    @Test
    func parsesEightBitHeartRate() throws {
        let data = Data([0b0000_0000, 72])

        #expect(try HeartRateMeasurementParser.parse(data) == 72)
    }

    @Test
    func parsesSixteenBitHeartRateUsingLittleEndian() throws {
        let data = Data([0b0000_0001, 0x2C, 0x01])

        #expect(try HeartRateMeasurementParser.parse(data) == 300)
    }

    @Test
    func rejectsEmptyData() {
        #expect(throws: HeartRateMeasurementParser.ParseError.missingFlags) {
            try HeartRateMeasurementParser.parse(Data())
        }
    }

    @Test
    func rejectsTruncatedEightBitMeasurement() {
        #expect(throws: HeartRateMeasurementParser.ParseError.missingHeartRateValue) {
            try HeartRateMeasurementParser.parse(Data([0b0000_0000]))
        }
    }

    @Test
    func rejectsTruncatedSixteenBitMeasurement() {
        #expect(throws: HeartRateMeasurementParser.ParseError.missingHeartRateValue) {
            try HeartRateMeasurementParser.parse(Data([0b0000_0001, 0x2C]))
        }
    }
}

private enum HeartRateMeasurementParser {
    enum ParseError: Error, Equatable {
        case missingFlags
        case missingHeartRateValue
    }

    static func parse(_ data: Data) throws -> Int {
        guard let flags = data.first else {
            throw ParseError.missingFlags
        }

        if flags & 0x01 != 0 {
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
