import UIKit

class KeyboardViewController: UIInputViewController {

    private var isUppercase = true
    private var isNumbers = false
    private var lastPressTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.30
    private var mainStackView: UIStackView!

    private let azertyRows = [
        ["A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"],
        ["SHIFT", "W", "X", "C", "V", "B", "N", "'", "DEL"],
        ["123", "SPACE", ".", "?", "!", "RETURN"]
    ]

    private let numberRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""],
        ["ABC", ".", ",", "?", "!", "'", "+", "=", "DEL"],
        ["ABC", "SPACE", "_", "-", "/", "RETURN"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardInterface()
    }

    private func setupKeyboardInterface() {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = UIColor(white: 0.85, alpha: 1.0)

        mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fillEqually
        mainStackView.spacing = 8
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStackView)

        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 300)
        heightConstraint.priority = .required
        heightConstraint.isActive = true

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])

        let currentRows = isNumbers ? numberRows : azertyRows

        for row in currentRows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillProportionally
            rowStack.spacing = 6

            for key in row {
                let button = createKeyButton(title: key)
                rowStack.addArrangedSubview(button)
            }
            mainStackView.addArrangedSubview(rowStack)
        }
    }

    private func createKeyButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 8
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 0.5
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)

        switch title {
        case "SHIFT":
            button.setTitle(isUppercase ? "⇧ MAJ" : "⇧ min", for: .normal)
            button.backgroundColor = isUppercase ? UIColor.systemBlue : UIColor.systemGray3
            button.setTitleColor(isUppercase ? .white : .black, for: .normal)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 85).isActive = true

        case "DEL":
            button.setTitle("⌫", for: .normal)
            button.backgroundColor = UIColor.systemGray3
            button.setTitleColor(.black, for: .normal)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 85).isActive = true

        case "123", "ABC":
            button.setTitle(title, for: .normal)
            button.backgroundColor = UIColor.systemGray3
            button.setTitleColor(.black, for: .normal)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 85).isActive = true

        case "SPACE":
            button.setTitle("Espace", for: .normal)
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        case "RETURN":
            button.setTitle("Envoyer / ↵", for: .normal)
            button.backgroundColor = UIColor.systemBlue
            button.setTitleColor(.white, for: .normal)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 130).isActive = true

        default:
            let displayChar = isUppercase ? title.uppercased() : title.lowercased()
            button.setTitle(displayChar, for: .normal)
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
        }

        button.accessibilityIdentifier = title
        button.addTarget(self, action: #selector(keyPressed(_:)), for: .touchDown)
        return button
    }

    @objc private func keyPressed(_ sender: UIButton) {
        let now = Date().timeIntervalSince1970
        if now - lastPressTime < debounceInterval {
            return
        }
        lastPressTime = now

        let originalColor = sender.backgroundColor
        sender.backgroundColor = UIColor.systemGray4
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sender.backgroundColor = originalColor
        }

        guard let key = sender.accessibilityIdentifier else { return }

        switch key {
        case "SHIFT":
            isUppercase.toggle()
            setupKeyboardInterface()
        case "DEL":
            textDocumentProxy.deleteBackward()
        case "123":
            isNumbers = true
            setupKeyboardInterface()
        case "ABC":
            isNumbers = false
            setupKeyboardInterface()
        case "SPACE":
            textDocumentProxy.insertText(" ")
        case "RETURN":
            textDocumentProxy.insertText("\n")
        default:
            let charToInsert = isUppercase ? key.uppercased() : key.lowercased()
            textDocumentProxy.insertText(charToInsert)
            if isUppercase && key.rangeOfCharacter(from: .letters) != nil {
                isUppercase = false
                setupKeyboardInterface()
            }
        }
    }
}
