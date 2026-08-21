import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // The layout has a floor below which it has nothing sensible to show: the
    // navigation still needs its room and a row of posters still needs to fit.
    // Left unset, the window can be dragged down to a sliver and every screen
    // in the app overflows at once.
    self.minSize = NSSize(width: 480, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
