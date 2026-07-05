import UIKit
import SnapKit

// MARK: - ActivityViewController

/// Activity 탭 placeholder 화면.
///
/// 실제 활동 기록 화면이 구현되기 전까지 탭 구조를 유지하기 위한 임시 화면이다.
final class ActivityViewController: UIViewController {

    // MARK: - UI

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Activity Tab (Coming Soon)"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    // MARK: - Configuration

    private func configureUI() {
        title = "Activity"
        view.backgroundColor = .systemBackground

        view.addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
