//
//  nostrnodeApp.swift
//  nostrnode
//
//  Created by Peter Denton on 3/28/23.
//

import SwiftUI

@main
struct nostrnodeApp: App {
    @StateObject private var manager: DataManager = DataManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .environment(\.managedObjectContext, manager.container.viewContext)
        }
    }
}
