import XCTest
@testable import BeePeachRoutiner

@MainActor
final class SessionControlCapsuleTests: XCTestCase {

    // MARK: - Callbacks

    func test_tapPlayPauseButton_shouldInvokeOnPlayPauseTapped() {
        // Given
        let sut = makeSUT()
        var tapCount = 0
        sut.onPlayPauseTapped = { tapCount += 1 }

        // When
        sut.playPauseButtonForTest?.sendActions(for: .touchUpInside)

        // Then
        XCTAssertEqual(tapCount, 1)
    }

    func test_tapStopButton_shouldInvokeOnStopTapped() {
        // Given: stop 은 세션이 있는 상태에서만 활성화된다
        let sut = makeSUT()
        sut.state = .running
        var tapCount = 0
        sut.onStopTapped = { tapCount += 1 }

        // When
        sut.stopButtonForTest?.sendActions(for: .touchUpInside)

        // Then
        XCTAssertEqual(tapCount, 1)
    }

    func test_tapStopButton_shouldNotInvokeOnPlayPauseTapped() {
        // Given
        let sut = makeSUT()
        sut.state = .running
        var playPauseTapCount = 0
        sut.onPlayPauseTapped = { playPauseTapCount += 1 }

        // When
        sut.stopButtonForTest?.sendActions(for: .touchUpInside)

        // Then
        XCTAssertEqual(playPauseTapCount, 0)
    }

    // MARK: - State

    func test_state_shouldShowPauseIcon_whenRunning() {
        // Given
        let sut = makeSUT()

        // When
        sut.state = .running

        // Then
        XCTAssertEqual(
            sut.playPauseButtonForTest?.currentImage,
            UIImage(systemName: "pause.fill")
        )
    }

    func test_state_shouldShowPlayIcon_whenPausedAfterRunning() {
        // Given
        let sut = makeSUT()
        sut.state = .running

        // When
        sut.state = .paused

        // Then
        XCTAssertEqual(
            sut.playPauseButtonForTest?.currentImage,
            UIImage(systemName: "play.fill")
        )
    }

    func test_state_shouldDisableStopButton_whenIdle() {
        // Given / When: 초기 상태 idle — 종료할 세션이 없다
        let sut = makeSUT()

        // Then
        XCTAssertEqual(sut.stopButtonForTest?.isEnabled, false)
    }

    func test_state_shouldEnableStopButton_whenRunning() {
        // Given
        let sut = makeSUT()

        // When
        sut.state = .running

        // Then
        XCTAssertEqual(sut.stopButtonForTest?.isEnabled, true)
    }

    // MARK: - Layout

    func test_layout_shouldBePillShape() {
        // Given / When
        let sut = makeSUT()

        // Then: pill = cornerRadius 가 높이의 절반
        XCTAssertGreaterThan(sut.bounds.height, 0)
        XCTAssertEqual(sut.layer.cornerRadius, sut.bounds.height / 2)
    }

    func test_layout_shouldContainStopAndPlayPauseButtons() {
        // Given / When
        let sut = makeSUT()

        // Then: [stop][play/pause] 순서의 버튼 2개
        XCTAssertEqual(sut.buttonsForTest.count, 2)
        XCTAssertEqual(sut.stopButtonForTest?.tintColor, .systemRed)
        XCTAssertEqual(
            sut.playPauseButtonForTest?.currentImage,
            UIImage(systemName: "play.fill")
        )
    }

    // MARK: - Helpers

    private func makeSUT() -> SessionControlCapsule {
        let view = SessionControlCapsule(frame: CGRect(x: 0, y: 0, width: 120, height: 64))
        view.layoutIfNeeded()
        return view
    }
}

private extension SessionControlCapsule {
    /// stack 배치 순서: [stop, playPause]. 버튼은 private 이므로 subview 트리로 접근한다.
    var buttonsForTest: [UIButton] {
        let stackView = subviews.compactMap { $0 as? UIStackView }.first
        return stackView?.arrangedSubviews.compactMap { $0 as? UIButton } ?? []
    }

    var stopButtonForTest: UIButton? { buttonsForTest.first }
    var playPauseButtonForTest: UIButton? { buttonsForTest.last }
}
