import XCTest
@testable import BeePeachRoutiner

@MainActor
final class WorkLogModalViewControllerTests: XCTestCase {

    // MARK: - onComplete

    /// present 없이 테스트하므로 dismiss 는 no-op — viewDidDisappear 직접 호출로
    /// "모달이 닫힌 뒤" 를 시뮬레이션한다.
    func test_saveTapped_shouldCompleteWithTrimmedText_whenTextEntered() {
        // Given
        let sut = makeSUT()
        var captured: [String?] = []
        sut.onComplete = { captured.append($0) }
        sut.textView.text = "  회의록 작성  "

        // When
        sut.saveButton.sendActions(for: .touchUpInside)
        sut.viewDidDisappear(false)

        // Then
        XCTAssertEqual(captured, ["회의록 작성"])
    }

    func test_saveTapped_shouldCompleteWithNil_whenTextIsWhitespaceOnly() {
        // Given
        let sut = makeSUT()
        var captured: [String?] = []
        sut.onComplete = { captured.append($0) }
        sut.textView.text = "   \n  "

        // When
        sut.saveButton.sendActions(for: .touchUpInside)
        sut.viewDidDisappear(false)

        // Then
        XCTAssertEqual(captured, [nil])
    }

    func test_closeTapped_shouldCompleteWithNil_evenWhenTextEntered() {
        // Given
        let sut = makeSUT()
        var captured: [String?] = []
        sut.onComplete = { captured.append($0) }
        sut.textView.text = "버려질 메모"

        // When
        sut.closeButton.sendActions(for: .touchUpInside)
        sut.viewDidDisappear(false)

        // Then
        XCTAssertEqual(captured, [nil])
    }

    func test_swipeDismiss_shouldCompleteWithNil_whenNoButtonTapped() {
        // Given: 버튼 없이 스와이프로 닫히는 경로 — viewDidDisappear 만 발생
        let sut = makeSUT()
        var captured: [String?] = []
        sut.onComplete = { captured.append($0) }
        sut.textView.text = "버려질 메모"

        // When
        sut.viewDidDisappear(false)

        // Then: 기록 자체는 유실되면 안 되므로 nil 로라도 완료가 전달돼야 한다
        XCTAssertEqual(captured, [nil])
    }

    func test_viewDidDisappear_shouldCompleteOnlyOnce_whenCalledTwice() {
        // Given
        let sut = makeSUT()
        var completeCount = 0
        sut.onComplete = { _ in completeCount += 1 }

        // When
        sut.viewDidDisappear(false)
        sut.viewDidDisappear(false)

        // Then
        XCTAssertEqual(completeCount, 1)
    }

    // MARK: - Placeholder

    func test_textViewDidChange_shouldHidePlaceholder_whenTextEntered() {
        // Given
        let sut = makeSUT()
        sut.textView.text = "작업 내용"

        // When
        sut.textViewDidChange(sut.textView)

        // Then
        XCTAssertTrue(sut.placeholderLabel.isHidden)
    }

    func test_textViewDidChange_shouldShowPlaceholder_whenTextCleared() {
        // Given
        let sut = makeSUT()
        sut.textView.text = "작업 내용"
        sut.textViewDidChange(sut.textView)

        // When
        sut.textView.text = ""
        sut.textViewDidChange(sut.textView)

        // Then
        XCTAssertFalse(sut.placeholderLabel.isHidden)
    }

    // MARK: - Presentation

    func test_init_shouldConfigureMediumDetentSheet() {
        // Given / When
        let sut = WorkLogModalViewController()

        // Then
        XCTAssertEqual(sut.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(sut.sheetPresentationController?.detents, [.medium()])
    }

    // MARK: - Helpers

    private func makeSUT() -> WorkLogModalViewController {
        let viewController = WorkLogModalViewController()
        viewController.loadViewIfNeeded()
        return viewController
    }
}
