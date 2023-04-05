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
        print("retrieve")
        DispatchQueue.main.async {
            let context = DataManager.shared.container.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Credentials")
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.resultType = .dictionaryResultType
            
            do {
                if let results = try context.fetch(fetchRequest) as? [[String:Any]], results.count > 0 {
                    completion(results[0])
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }
    }
    
    class func deleteAllData(completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            let context = DataManager.shared.container.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Credentials")
            fetchRequest.returnsObjectsAsFaults = false
            do {
                let stuff = try context.fetch(fetchRequest)
                for thing in stuff as! [NSManagedObject] {
                    context.delete(thing)
                }
                try context.save()
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
    
    class func saveEntity(dict: [String:Any], completion: @escaping ((Bool)) -> Void) {
        print("save")
        DispatchQueue.main.async {

            let context = DataManager.shared.container.viewContext

            guard let entity = NSEntityDescription.entity(forEntityName: "Credentials", in: context) else {
                completion(false)
                return
            }

            let credential = NSManagedObject(entity: entity, insertInto: context)
            var success = false

            for (key, value) in dict {
                credential.setValue(value, forKey: key)
                do {
                    try context.save()
                    success = true
                } catch {
                    success = false
                }
            }
            completion(success)
        }
    }
    
    class func update(keyToUpdate: String, newValue: Any, completion: @escaping ((Bool)) -> Void) {
        DispatchQueue.main.async {
            let context = DataManager.shared.container.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Credentials")
            fetchRequest.returnsObjectsAsFaults = false
            do {
                let credentials = try context.fetch(fetchRequest)
                let credential = credentials[0] as! NSManagedObject
                credential.setValue(newValue, forKey: keyToUpdate)
                try context.save()
                completion(true)
            } catch {
                completion(false)
            }
        }
    }    
}
