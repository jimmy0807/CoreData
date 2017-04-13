//
//  TPCoreDataManager.swift
//  aaa
//
//  Created by jimmy on 17/2/2.
//  Copyright © 2017年 xxx. All rights reserved.
//

import UIKit
import CoreData

private var currentUserName : String?
private let coreDataKey = "TPCoreDataManager"

class TPCoreDataManager: NSObject
{
    private var currentUser : String?
    private static let writeDispatch_queue : DispatchQueue = DispatchQueue.init(label: "cd_write")
    
    lazy var managedObjectModel : NSManagedObjectModel = {
        let modelPath = Bundle.main.path(forResource: "Boss", ofType: "momd")!
        let modelURL = URL(fileURLWithPath: modelPath)
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator : NSPersistentStoreCoordinator = {
        let storeFile = currentUserName! + ".sqlite"
        let directory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last! as NSString
        let storeURL = URL(fileURLWithPath: directory.appendingPathComponent(storeFile))
        let options = [NSMigratePersistentStoresAutomaticallyOption:true,NSInferMappingModelAutomaticallyOption:true]
        
        var psc = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        do
        {
            try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
        }
        catch
        {
            
        }
        
        return psc
    }()
    
    lazy var managedObjectContext : NSManagedObjectContext = {
        var context : NSManagedObjectContext!
        
        let coordinator = self.persistentStoreCoordinator
        
        if Thread.current.isMainThread
        {
            context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        }
        else
        {
            context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        }
        
        context.persistentStoreCoordinator = coordinator
        
        return context
    }()
    
    open class func setCurrentUserName(_ name : String!)
    {
        currentUserName = name
        _ = TPCoreDataManager.current()
    }
    
    open class func current() -> TPCoreDataManager
    {
        let threadParams = Thread.current.threadDictionary
        var cdm = threadParams[coreDataKey] as? TPCoreDataManager
        
        if  let name = currentUserName, !name.isEmpty
        {
            
        }
        else
        {
            currentUserName = "default"
        }
        
        if let _cdm = cdm, let userName = _cdm.currentUser, userName != currentUserName!
        {
            cdm = nil
            threadParams.removeObject(forKey: coreDataKey)
        }
        
        guard let _ = cdm else {
            if Thread.current.isMainThread
            {
                cdm = TPCoreDataManager()
                NotificationCenter.default.addObserver(cdm!.managedObjectContext, selector: #selector(cdm?.managedObjectContext.mergeChanges), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
                cdm?.managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            }
            else
            {
                cdm = TPCoreDataManager.createForOtherThread()
            }
            
            cdm?.currentUser = currentUserName
            threadParams[coreDataKey] = cdm
            
            return cdm!
        }
 
        return cdm!
    }
    
    open class func createForOtherThread() -> TPCoreDataManager
    {
        let cdMgr = TPCoreDataManager()
        if let mainThreadcdMgr = Thread.main.threadDictionary[coreDataKey] as? TPCoreDataManager
        {
            cdMgr.managedObjectModel  = mainThreadcdMgr.managedObjectModel
            cdMgr.persistentStoreCoordinator = mainThreadcdMgr.persistentStoreCoordinator
            cdMgr.currentUser = mainThreadcdMgr.currentUser;
        }
        
        cdMgr.managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        cdMgr.managedObjectContext.persistentStoreCoordinator = cdMgr.persistentStoreCoordinator;
        
        return cdMgr
    }
    
    open func save()
    {
        do
        {
            try managedObjectContext.save()
        }
        catch{}
    }

    open func rollback()
    {
        managedObjectContext.rollback()
    }

    open func deleteObject(_ object: NSManagedObject)
    {
        managedObjectContext.delete(object)
    }
    
    open func deleteObjects(_ objects: [NSManagedObject]?)
    {
        if let array = objects
        {
            for (_,object) in array.enumerated()
            {
                deleteObject(object)
            }
        }
    }
    
    open func insertEntity<T: NSManagedObject>() -> T
    {
        return NSEntityDescription.insertNewObject(forEntityName: NSStringFromClass(T.self as AnyClass), into: managedObjectContext) as! T
    }
    
    open func uniqueEntity<T: NSManagedObject>(withValue value: Any, forKey key: String) -> T?
    {
        if let entity: T = findEntity(withValue: value, forKey: key)
        {
            return entity
        }
        
        let entity: T = NSEntityDescription.insertNewObject(forEntityName: NSStringFromClass(T.self as AnyClass), into: managedObjectContext) as! T
        entity.setValue(value, forKey: key)
        
        return entity
    }
    
    open func findEntity<T>(withValue value: Any, forKey key: String) -> T?
    {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: NSStringFromClass(T.self as! AnyClass))
        fetchRequest.predicate = NSPredicate(format: "\(key) = %@", value as! CVarArg)
        
        var results :[NSManagedObject]?
        do
        {
            results = try managedObjectContext.fetch(fetchRequest)
        }catch{
            
        }
        
        return results?.last as? T
    }
    
    open func findEntity<T>(_ predicateString: String) -> T?
    {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: NSStringFromClass(T.self as! AnyClass))
        fetchRequest.predicate = NSPredicate(format: predicateString)
        
        var results :[NSManagedObject]?
        do
        {
            results = try managedObjectContext.fetch(fetchRequest)
        }catch{
            
        }
        
        return results?.last as? T
    }
    
    open func fetchItems<T: NSManagedObject>(sortedKey key: String = "", ascending: Bool = true, predicate: NSPredicate? = nil) -> [T]
    {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: NSStringFromClass(T.self as AnyClass))
        
        if key.characters.count > 0
        {
            let des = NSSortDescriptor(key: key, ascending: ascending)
            fetchRequest.sortDescriptors = [des]
        }
        
        fetchRequest.predicate = predicate
        
        var results :[NSManagedObject]?
        do
        {
            results = try managedObjectContext.fetch(fetchRequest)
        }catch{
            print("no item find")
        }
        
        if let array = results
        {
            return array as! [T]
        }
        
        return []
    }
    
    open class func performBlockOnWriteQueue(_ fn: @escaping ()->Void)
    {
        writeDispatch_queue.async {
            fn()
        }
    }
}

