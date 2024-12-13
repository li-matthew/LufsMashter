//
//  LufsMashterApp.swift
//  LufsMashter
//
//  Created by mashen on 12/12/24.
//

import SwiftUI

@main
struct LufsMashterApp: App {
    @State private var hostModel = AudioUnitHostModel()

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
