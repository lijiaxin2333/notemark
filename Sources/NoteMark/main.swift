import AppKit

if let status = CommandLineTool.runBeforeLaunch(CommandLine.arguments) { exit(status) }
let application = NSApplication.shared
if let status = CommandLineTool.runRenderer(CommandLine.arguments) { exit(status) }
let delegate = AppDelegate()
application.delegate = delegate
application.run()
