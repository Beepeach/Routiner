import XCTest
@testable import BeePeachRoutiner

final class TimeWheelPickerViewTests: XCTestCase {

    // MARK: - components

    func test_components_shouldBeMinutesAndSeconds_whenMaxDurationIsSixtyMinutes() {
        // Given / When
        let sut = makeSUT(maxDuration: 60 * 60)

        // Then: 분 0~60 (61 rows) — 풀 스케일 60:00 직접 선택 가능, 초 0~59 (60 rows)
        XCTAssertEqual(sut.numberOfComponents(in: sut), 2)
        XCTAssertEqual(sut.pickerView(sut, numberOfRowsInComponent: 0), 61)
        XCTAssertEqual(sut.pickerView(sut, numberOfRowsInComponent: 1), 60)
    }

    func test_titleForRow_shouldFormatMinutesAndSeconds() {
        // Given
        let sut = makeSUT()

        // When / Then
        XCTAssertEqual(sut.pickerView(sut, titleForRow: 25, forComponent: 0), "25m")
        XCTAssertEqual(sut.pickerView(sut, titleForRow: 30, forComponent: 1), "30s")
    }

    // MARK: - setDuration

    func test_setDuration_shouldSelectMatchingRows() {
        // Given
        let sut = makeSUT()

        // When: 25분 30초
        sut.setDuration(1530)

        // Then
        XCTAssertEqual(sut.selectedRow(inComponent: 0), 25)
        XCTAssertEqual(sut.selectedRow(inComponent: 1), 30)
    }

    func test_setDuration_shouldNotEmitCallback() {
        // Given: 시스템 주입은 콜백 미발화 규약 (동기화 무한루프 차단)
        let sut = makeSUT()
        var emitCount = 0
        sut.onDurationChanged = { _ in emitCount += 1 }

        // When
        sut.setDuration(1530)

        // Then
        XCTAssertEqual(emitCount, 0)
    }

    func test_setDuration_shouldClampToMax_whenAboveRange() {
        // Given: maxDuration 60분
        let sut = makeSUT(maxDuration: 60 * 60)

        // When: 61분 주입
        sut.setDuration(61 * 60)

        // Then: 60:00 으로 clamp
        XCTAssertEqual(sut.selectedRow(inComponent: 0), 60)
        XCTAssertEqual(sut.selectedRow(inComponent: 1), 0)
    }

    func test_setDuration_shouldClampToZero_whenNegative() {
        // Given
        let sut = makeSUT()
        sut.setDuration(1530)

        // When
        sut.setDuration(-10)

        // Then
        XCTAssertEqual(sut.selectedRow(inComponent: 0), 0)
        XCTAssertEqual(sut.selectedRow(inComponent: 1), 0)
    }

    // MARK: - didSelectRow

    func test_didSelectRow_shouldEmitDuration_whenWithinRange() {
        // Given
        let sut = makeSUT()
        var captured: [TimeInterval] = []
        sut.onDurationChanged = { captured.append($0) }

        // When: 사용자가 25m / 30s 로 돌린 상황 재현 (programmatic set 후 delegate 직접 호출)
        sut.setDuration(1530)
        sut.pickerView(sut, didSelectRow: 30, inComponent: 1)

        // Then
        XCTAssertEqual(captured, [1530])
    }

    func test_didSelectRow_shouldEmitClampedDuration_whenTotalExceedsMax() {
        // Given: maxDuration 60분에서 60m 선택 상태
        let sut = makeSUT(maxDuration: 60 * 60)
        sut.setDuration(60 * 60)
        var captured: [TimeInterval] = []
        sut.onDurationChanged = { captured.append($0) }

        // When: 초 휠을 30 으로 돌림 → 합계 60m 30s (상한 초과)
        sut.selectRow(30, inComponent: 1, animated: false)
        sut.pickerView(sut, didSelectRow: 30, inComponent: 1)

        // Then: clamp 값 1회 방출
        XCTAssertEqual(captured, [3600])
    }

    func test_didSelectRow_shouldSnapSecondsRowToZero_whenClamped() {
        // Given
        let sut = makeSUT(maxDuration: 60 * 60)
        sut.setDuration(60 * 60)

        // When: 60m 30s 초과 조합
        sut.selectRow(30, inComponent: 1, animated: false)
        sut.pickerView(sut, didSelectRow: 30, inComponent: 1)

        // Then: 초 휠이 0 으로 스냅백 (clamp 시각 피드백)
        XCTAssertEqual(sut.selectedRow(inComponent: 1), 0)
    }

    // MARK: - Helpers

    private func makeSUT(maxDuration: TimeInterval = 60 * 60) -> TimeWheelPickerView {
        let view = TimeWheelPickerView(maxDuration: maxDuration)
        view.frame = CGRect(x: 0, y: 0, width: 300, height: 216)
        view.layoutIfNeeded()
        return view
    }
}
