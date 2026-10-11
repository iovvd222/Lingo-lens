//
//  SavedTranslation+CoreDataProperties.swift
//  Lingo lens
//
//  Created by Abhyas Mall on 3/9/25.
//
//

import Foundation
import CoreData


extension SavedTranslation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SavedTranslation> {
        return NSFetchRequest<SavedTranslation>(entityName: "SavedTranslation")
    }

    @NSManaged public var dateAdded: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var languageCode: String?
    @NSManaged public var languageName: String?
    @NSManaged public var originalText: String?
    @NSManaged public var translatedText: String?
    @NSManaged public var ipa: String?
    @NSManaged public var partOfSpeech: String?
    @NSManaged public var collocationsJSON: String?
    @NSManaged public var examplesJSON: String?

}

extension SavedTranslation : Identifiable {

}
