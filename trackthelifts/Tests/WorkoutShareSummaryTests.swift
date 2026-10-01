import XCTest
@testable import trackthelifts

final class WorkoutShareSummaryTests: XCTestCase {
    func testNoHistoryIsNeverARecord() {
        XCTAssertNil(PersonalRecordService.bestRecord(
            among: [LiftPerformance(weight: 315, reps: 1)],
            history: []
        ))
    }

    func testHeavierWeightWinsAndPrefersMoreRepsOnTies() {
        let record = PersonalRecordService.bestRecord(
            among: [
                LiftPerformance(weight: 235, reps: 2),
                LiftPerformance(weight: 235, reps: 3),
                LiftPerformance(weight: 185, reps: 10),
            ],
            history: [LiftPerformance(weight: 225, reps: 5)]
        )
        XCTAssertEqual(record?.kind, .weight)
        XCTAssertEqual(record?.performance, LiftPerformance(weight: 235, reps: 3))
    }

    func testEstimatedOneRepMaxBeatsVolumeWhenWeightIsNotANewBest() {
        let record = PersonalRecordService.bestRecord(
            among: [LiftPerformance(weight: 225, reps: 8)],
            history: [LiftPerformance(weight: 225, reps: 5)]
        )
        XCTAssertEqual(record?.kind, .estimated1RM)
    }

    func testVolumeRecordForLighterHighRepSet() {
        let record = PersonalRecordService.bestRecord(
            among: [LiftPerformance(weight: 100, reps: 30)],
            history: [LiftPerformance(weight: 200, reps: 12), LiftPerformance(weight: 120, reps: 20)]
        )
        XCTAssertEqual(record?.kind, .volume)
        XCTAssertEqual(record?.performance, LiftPerformance(weight: 100, reps: 30))
    }

    func testMatchingPreviousBestIsNotARecord() {
        XCTAssertNil(PersonalRecordService.bestRecord(
            among: [LiftPerformance(weight: 225, reps: 5)],
            history: [LiftPerformance(weight: 225, reps: 5)]
        ))
    }

    func testCompactNumberFormatting() {
        XCTAssertEqual(WorkoutShareSummary.compactNumber(0), "0")
        XCTAssertEqual(WorkoutShareSummary.compactNumber(9_875), "9,875")
        XCTAssertEqual(WorkoutShareSummary.compactNumber(12_000), "12K")
        XCTAssertEqual(WorkoutShareSummary.compactNumber(12_480), "12.4K")
        XCTAssertEqual(WorkoutShareSummary.compactNumber(1_250_000), "1.25M")
    }
}
