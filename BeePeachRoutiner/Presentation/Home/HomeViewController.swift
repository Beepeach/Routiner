import UIKit

final class HomeViewController: UIViewController {

    // MARK: - UI Components

    private let greetingLabel: UILabel = {
        let label = UILabel()
        label.text = "안녕하세요"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(greetingLabel)

        NSLayoutConstraint.activate([
            greetingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            greetingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
