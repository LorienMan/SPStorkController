import UIKit

class ModalTableViewController: UIViewController {
    
    let navBar = SPFakeBarView(style: .stork)
    let tableView = UITableView()
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    
    private var data = ["Assembly", "C", "C++", "Java", "JavaScript", "Php", "Python", "Swift", "Kotlin", "Assembly", "C", "C++", "Java", "JavaScript", "Php", "Python", "Objective-C", "Swift", "Kotlin", "Assembly", "C", "C++", "Java", "JavaScript", "Php", "Python", "Objective-C"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        self.modalPresentationCapturesStatusBarAppearance = true

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.tableView.contentInset.top = self.navBar.height
        self.tableView.scrollIndicatorInsets.top = self.navBar.height
        self.view.addSubview(self.tableView)
        
        self.navBar.titleLabel.text = "Table"
        self.navBar.leftButton.setTitle("Cancel", for: .normal)
        self.navBar.leftButton.addTarget(self, action: #selector(self.dismissAction), for: .touchUpInside)
        self.view.addSubview(self.navBar)
        
        self.updateLayout(with: self.view.frame.size)

        let presentationController = self.presentationController as? SPStorkPresentationControllerProtocol
        presentationController?.scrollView = tableView
        presentationController?.scaleEnabled = true
        presentationController?.frictionEnabled = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.updateLayout(with: self.view.frame.size)

        let presentationController = self.presentationController as? SPStorkPresentationControllerProtocol
        presentationController?.updateCustomHeight(self.view.frame.size.width)
    }
    
    func updateLayout(with size: CGSize) {
        self.tableView.frame = CGRect.init(x: 0, y: 0, width: size.width, height: size.height)
    }
    
    @objc func dismissAction() {
        self.dismiss()
    }
}

extension ModalTableViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = data[indexPath.row]
        cell.transform = .identity
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
}

extension ModalTableViewController: UITableViewDelegate {
}

