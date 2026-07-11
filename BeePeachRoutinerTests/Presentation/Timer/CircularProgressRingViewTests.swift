import XCTest
@testable import BeePeachRoutiner

@MainActor
final class CircularProgressRingViewTests: XCTestCase {

    // MARK: - setRatio

    func test_setRatio_shouldSetStrokeEndExactly_whenWithinRange() {
        // Given
        let sut = makeSUT()

        // When
        sut.setRatio(0.5)

        // Then
        XCTAssertEqual(sut.progressShapeLayer?.strokeEnd, 0.5)
    }

    func test_setRatio_shouldClampToZero_whenBelowRange() {
        // Given
        let sut = makeSUT()

        // When
        sut.setRatio(-0.5)

        // Then
        XCTAssertEqual(sut.progressShapeLayer?.strokeEnd, 0)
    }

    func test_setRatio_shouldClampToOne_whenAboveRange() {
        // Given
        let sut = makeSUT()

        // When
        sut.setRatio(1.5)

        // Then
        XCTAssertEqual(sut.progressShapeLayer?.strokeEnd, 1)
    }

    // MARK: - applyDeltaAngle (Pan 누적 델타 + clamp + snap)

    func test_applyDeltaAngle_shouldClampToOne_whenExceedingMaximum() {
        // Given: ratio 가 이미 1.0 (시계 한 바퀴 완료)
        let sut = makeSUT()
        sut.setRatio(1.0)

        // When: 더 시계방향 회전 시도 (+0.125 ratio)
        sut.applyDeltaAngle(.pi / 4)

        // Then: 1.0 에서 멈춰야 함 (wrap 차단)
        XCTAssertEqual(sut.progressShapeLayer?.strokeEnd, 1.0)
    }

    func test_applyDeltaAngle_shouldClampToZero_whenBelowMinimum() {
        // Given: ratio 가 이미 0
        let sut = makeSUT()
        sut.setRatio(0.0)

        // When: 시계 반대 회전 시도 (-0.125 ratio)
        sut.applyDeltaAngle(-.pi / 4)

        // Then: 0 에서 멈춰야 함 (wrap 차단)
        XCTAssertEqual(sut.progressShapeLayer?.strokeEnd, 0)
    }

    func test_applyDeltaAngle_shouldSnapToStep_whenSnapStepConfigured() {
        // Given: 1/60 (1분) 스냅, ratio 0.5
        let sut = makeSUT()
        sut.snapStep = 1.0 / 60.0
        sut.setRatio(0.5)

        // When: ratio +0.01 만큼 회전 (1/60 보다 살짝 작음 → 다음 step 31/60 으로 스냅)
        sut.applyDeltaAngle(2 * .pi * 0.01)

        // Then
        let strokeEnd = Double(sut.progressShapeLayer?.strokeEnd ?? -1)
        XCTAssertEqual(strokeEnd, 31.0 / 60.0, accuracy: 0.0001)
    }

    func test_applyDeltaAngle_shouldEmitCallback_whenSnappedRatioChanges() {
        // Given
        let sut = makeSUT()
        sut.snapStep = 1.0 / 60.0
        sut.setRatio(0)
        var captured: [CGFloat] = []
        sut.onRatioChanged = { captured.append($0) }

        // When: 정확히 1분(=1/60) 만큼 회전
        sut.applyDeltaAngle(2 * .pi / 60)

        // Then
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(Double(captured.last ?? -1), 1.0 / 60.0, accuracy: 0.0001)
    }

    func test_applyDeltaAngle_shouldNotEmitCallback_whenSnappedRatioUnchanged() {
        // Given
        let sut = makeSUT()
        sut.snapStep = 1.0 / 60.0
        sut.setRatio(0)
        var emitCount = 0
        sut.onRatioChanged = { _ in emitCount += 1 }

        // When: 1분 step 의 절반보다 작은 회전 (스냅 후 0 유지)
        sut.applyDeltaAngle(2 * .pi * (0.4 / 60))

        // Then
        XCTAssertEqual(emitCount, 0)
    }

    // MARK: - layout

    func test_layout_shouldAttachAllShapeLayers() {
        // Given / When
        let sut = makeSUT()

        // Then: track / progress / tick / knob — 총 4 개의 CAShapeLayer.
        let shapeLayers = sut.layer.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
        XCTAssertEqual(shapeLayers.count, 4)
        XCTAssertTrue(shapeLayers.allSatisfy { $0.path != nil })
    }

    func test_layout_shouldRenderKnobAtTwelveOClock_whenRatioIsZero() {
        // Given
        let sut = makeSUT()
        sut.setRatio(0)

        // When: knob layer (마지막 sublayer) 의 position.
        // knob path/bounds 는 setupLayers 에서 고정되고, 위치는 layer.position 으로만 관리한다.
        let shapeLayers = sut.layer.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
        let knobLayer = shapeLayers.last

        // Then: knob center 는 12시 (centerX, 위쪽)에 있어야 한다.
        XCTAssertEqual(knobLayer?.position.x ?? 0, sut.bounds.midX, accuracy: 0.5)
        XCTAssertLessThan(knobLayer?.position.y ?? .infinity, sut.bounds.midY)
    }

    // MARK: - hit zone

    func test_isWithinHitZone_shouldAcceptKnobArea_whenRatioIsZero() {
        // Given: ratio=0 → 12시 손잡이 근처만 hit 허용
        let sut = makeSUT()
        sut.setRatio(0)

        // When: 12시 손잡이 좌표 (view 가운데 위쪽 호 끝)
        let knob = CGPoint(x: sut.bounds.midX, y: sut.bounds.minY + 16)

        // Then
        XCTAssertTrue(sut.isWithinHitZone(knob))
    }

    func test_isWithinHitZone_shouldAcceptOffKnobAngle_whenRatioIsZeroOnLargeRing() {
        // Given: 큰 다이얼(600pt). 각도 윈도우는 화면 크기와 무관하게 12시 기준 ±N도를 잡아야 한다.
        // (절대 pt 캐치 반경 방식은 큰 화면에서 같은 각도라도 거리가 멀어져 놓친다.)
        let sut = makeSUT(size: 600)
        sut.setRatio(0)

        // When: 12시에서 약 35° 떨어진 호 위 점 (±45° 윈도우 안). r=284 → 노브 중심서 ~171pt.
        // 캐치 반경 방식이면 거부될 거리지만, 각도 윈도우면 35° < 45° 라 허용돼야 한다.
        let offKnobOnLargeRing = CGPoint(x: 463, y: 67)

        // Then
        XCTAssertTrue(sut.isWithinHitZone(offKnobOnLargeRing))
    }

    func test_isWithinHitZone_shouldRejectArbitraryRingPoint_whenRatioIsZero() {
        // Given: ratio=0 → 12시 외 다른 호 위치 hit 거부 (빈 트랙 점프 방지)
        let sut = makeSUT()
        sut.setRatio(0)

        // When: 3시 방향 호 위 좌표
        let threeOClock = CGPoint(x: sut.bounds.maxX - 16, y: sut.bounds.midY)

        // Then
        XCTAssertFalse(sut.isWithinHitZone(threeOClock))
    }

    func test_isWithinHitZone_shouldAcceptFilledArcPoint_whenRatioIsHalf() {
        // Given: ratio=0.5 → 채워진 호는 12시부터 시계방향으로 6시까지
        let sut = makeSUT()
        sut.setRatio(0.5)

        // When: 3시 방향 호 위 좌표 (ratio 약 0.25 위치 — 채워진 영역 안)
        let threeOClock = CGPoint(x: sut.bounds.maxX - 16, y: sut.bounds.midY)

        // Then
        XCTAssertTrue(sut.isWithinHitZone(threeOClock))
    }

    func test_isWithinHitZone_shouldRejectUnfilledArcPoint_whenRatioIsHalf() {
        // Given: ratio=0.5 → 6시 ~ 12시 (오른쪽 시계 반대 방향) 은 비어있는 영역
        let sut = makeSUT()
        sut.setRatio(0.5)

        // When: 9시 방향 호 위 좌표 (ratio 약 0.75 — 비어있는 영역)
        let nineOClock = CGPoint(x: sut.bounds.minX + 16, y: sut.bounds.midY)

        // Then
        XCTAssertFalse(sut.isWithinHitZone(nineOClock))
    }

    func test_isWithinHitZone_shouldRejectPointFarOutsideBand() {
        // Given
        let sut = makeSUT()
        sut.setRatio(1.0)

        // When: ring 중심점 (band 안쪽 한참 안)
        let center = CGPoint(x: sut.bounds.midX, y: sut.bounds.midY)

        // Then
        XCTAssertFalse(sut.isWithinHitZone(center))
    }

    // MARK: - Helpers

    private func makeSUT(size: CGFloat = 200) -> CircularProgressRingView {
        let view = CircularProgressRingView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.layoutIfNeeded()
        return view
    }
}

private extension CircularProgressRingView {
    /// sublayer 추가 순서: track → progress → knob. 인덱스 1 이 progress.
    var progressShapeLayer: CAShapeLayer? {
        let shapeLayers = layer.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
        return shapeLayers.indices.contains(1) ? shapeLayers[1] : nil
    }
}
