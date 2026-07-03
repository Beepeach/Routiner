import UIKit

// MARK: - TimeWheelPickerView

/// 분/초 두 컴포넌트로 duration 을 고르는 휠 피커. Digital Mode 의 입력 수단.
///
/// - 범위는 `maxDuration` 에서 파생된다: 분 0~(maxDuration/60), 초 0~59.
///   분을 상한까지 포함해 다이얼 풀 스케일(예: 60:00)과 대칭을 맞춘다.
/// - 합계가 `maxDuration` 을 넘는 조합(예: 60m 30s)은 clamp 하고
///   초 휠을 0 으로 스냅백해 시각 피드백을 준다.
/// - 자신이 dataSource/delegate 를 겸한다. `rx.itemSelected` 등 RxCocoa 확장을
///   이 뷰에 쓰지 말 것 — DelegateProxy 가 self-delegate 를 밀어내며 충돌한다.
final class TimeWheelPickerView: UIPickerView {

    // MARK: - Public API

    /// 사용자가 휠을 돌려 row 가 확정(snap)될 때 호출된다. clamp 적용된 값이 전달된다.
    /// `setDuration(_:animated:)` 같은 시스템 주입은 트리거하지 않는다.
    var onDurationChanged: ((TimeInterval) -> Void)?

    /// 외부에서 duration(초) 을 강제 설정한다. 시스템(timer 등) 갱신에 사용.
    /// `onDurationChanged` 는 발화하지 않는다 — programmatic `selectRow` 는
    /// UIKit 규약상 `didSelectRow` delegate 를 호출하지 않아 자연 보장된다.
    func setDuration(_ duration: TimeInterval, animated: Bool = false) {
        let clamped = self.clamped(duration)
        let total = Int(clamped)
        selectRow(total / 60, inComponent: Component.minutes.rawValue, animated: animated)
        selectRow(total % 60, inComponent: Component.seconds.rawValue, animated: animated)
    }

    // MARK: - Configuration

    private enum Component: Int, CaseIterable {
        case minutes = 0
        case seconds = 1
    }

    /// 휠이 표현할 수 있는 최대 시간(초). 분 컴포넌트 row 수를 파생한다.
    private let maxDuration: TimeInterval

    // MARK: - Haptics

    /// row 확정마다 selectionChanged() 를 호출해 다이얼과 동일한 촉감을 준다.
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // MARK: - Initialization

    init(maxDuration: TimeInterval = 60 * 60) {
        self.maxDuration = max(0, maxDuration)
        super.init(frame: .zero)
        dataSource = self
        delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Helpers

    private var minutesRowCount: Int {
        // 상한 분을 포함(0~max)해야 60:00 같은 풀 스케일을 직접 선택할 수 있다.
        Int(maxDuration / 60) + 1
    }

    private func clamped(_ duration: TimeInterval) -> TimeInterval {
        max(0, min(duration, maxDuration))
    }
}

// MARK: - UIPickerViewDataSource

extension TimeWheelPickerView: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        Component.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component) {
        case .minutes: return minutesRowCount
        case .seconds: return 60
        case nil: return 0
        }
    }
}

// MARK: - UIPickerViewDelegate

extension TimeWheelPickerView: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch Component(rawValue: component) {
        case .minutes: return "\(row)m"
        case .seconds: return "\(row)s"
        case nil: return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let minutes = selectedRow(inComponent: Component.minutes.rawValue)
        let seconds = selectedRow(inComponent: Component.seconds.rawValue)
        let raw = TimeInterval(minutes * 60 + seconds)
        let clamped = self.clamped(raw)

        // 상한 초과 조합(예: 60m 30s)은 초 휠을 0 으로 되돌려 clamp 를 시각화한다.
        if raw != clamped {
            selectRow(0, inComponent: Component.seconds.rawValue, animated: true)
        }

        selectionFeedback.selectionChanged()
        selectionFeedback.prepare() // 다음 스냅 발사 latency 감소
        onDurationChanged?(clamped)
    }
}
