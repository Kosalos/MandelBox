import UIKit

class HelpViewController: UIViewController {

    @IBOutlet var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        textView.font = UIFont(name: "Helvetica", size: 16)
        textView.resignFirstResponder()
        
        do {
            textView.text = try String(contentsOfFile: Bundle.main.path(forResource: "help.txt", ofType: "")!)
        } catch {
            fatalError("\n\nload help text failed\n\n")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        textView.scrollRangeToVisible(NSMakeRange(0, 0))
    }
}
