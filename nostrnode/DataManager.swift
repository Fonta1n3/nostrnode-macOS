//
//  DataManager.swift
//  nostrnode
//
//  Created by Peter Denton on 3/30/23.
//

import CoreData
import Foundation

/// Main data manager to handle the todo items
class DataManager: NSObject, ObservableObject {
    static let shared = DataManager()
    /// Dynamic properties that the UI will react to
    @Published var credentials: [Credentials] = [Credentials]()
    
    /// Add the Core Data container with the model name
    let container: NSPersistentContainer = NSPersistentContainer(name: "Model")
    
    /// Default init method. Load the Core Data container
    override init() {
        super.init()
        container.loadPersistentStores { _, _ in }
    }
    
    class func retrieve(completion: @escaping (([String:Any]?)) -> Void) {
        DispatchQueue.main.async {
            let context = DataManager.shared.container.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Credentials")
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.resultType = .dictionaryResultType
            
            do {
                if let results = try context.fetch(fetchRequest) as? [[String:Any]] {
                    completion(results[0])
                }
            } catch {
                completion(nil)
            }
        }
    }    
}
