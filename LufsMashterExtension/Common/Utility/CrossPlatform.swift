//
//  CrossPlatform.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import Foundation
import SwiftUI

#if os(iOS) || os(visionOS)
typealias HostingController = UIHostingController
#elseif os(macOS)
typealias HostingController = NSHostingController

extension NSView {
	
	func bringSubviewToFront(_ view: NSView) {
		// This function is a no-opp for macOS
	}
}
#endif
