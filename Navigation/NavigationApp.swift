//
//  NavigationApp.swift
//  Navigation
//
//  Created by Moosa Junad on 15/11/2025.
//

import SwiftUI

@main
struct NavigationApp: App {
    var body: some Scene {
        WindowGroup {
            NavStack {
                ContentView()
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}
