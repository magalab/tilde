import Darwin
import Foundation
import TildeApplication

if CommandLine.arguments.contains("--verify-resources") {
    exit(TildeApplicationLauncher.verifyResources() ? EXIT_SUCCESS : EXIT_FAILURE)
}

TildeApplicationLauncher.run()
