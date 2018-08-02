//
//  ACModel.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 13/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

import Foundation



open class ACAbstractItem {
    
    public  let OID : String
    public  let responseOID: String?
    public  let order: UInt?
    public  var loinc : String?
    
    public init(oid: String, responseOID: String?, order: UInt?) {
        self.OID = oid
        self.responseOID = responseOID
        self.order = order
    }
    
    public func listPropertiesWithValues(reflect: Mirror? = nil) {
        let mirror = reflect ?? Mirror(reflecting: self)
        if mirror.superclassMirror != nil {
            self.listPropertiesWithValues(reflect: mirror.superclassMirror)
        }
        
        for (index, attr) in mirror.children.enumerated() {
            if let property_name = attr.label as String! {
                print("\(mirror.description) \(index): \(property_name) = \(attr.value)")
            }
        }
    }
    
    
}
extension ACAbstractItem : Equatable {
    public static func  == (lhs: ACAbstractItem, rhs: ACAbstractItem) -> Bool {
        let areEqual = (lhs.OID == rhs.OID)
        return areEqual
    }
}

public class QuestionItem : ACAbstractItem {
    
    public final let question: String
    
    public init(oid: String, question: String, responseOID: String?, order: UInt?) {
        self.question = question
        super.init(oid: oid, responseOID: responseOID, order: order)
    }
    
    class func create(from json: JSONDict)-> QuestionItem? {
        
        if  let oid = json["ElementOID"] as? String,
            let question = json["Description"] as? String,
            let order = json["ElementOrder"] as? String {
            let qItem = QuestionItem(oid: oid, question: question, responseOID: nil, order: UInt(order)!)
          
            return qItem
        }
        return nil
    }
}

public class ResponseItem : ACAbstractItem {
    
    public final let text: String
    public final let value: String
    
    public init(oid: String, order: UInt, responseText: String, responseValue: String, responseOID: String) {
        self.text = responseText
        self.value = responseValue
        super.init(oid: oid, responseOID: responseOID, order: order)
    }
    
    class func create(from json: JSONDict) -> ResponseItem? {
        
        if let oid = json["ElementOID"] as? String,
           let response = json["Description"] as? String,
           let value = json["Value"] as? String,
           let responseOID = json["ItemResponseOID"] as? String,
           let order = json["Position"] as? String {
            
            let responseItem = ResponseItem(oid: oid, order: UInt(order)!, responseText: response, responseValue: value, responseOID: responseOID)
            if let loinc = json["LOINC_NUM"] as? String {
                responseItem.loinc = loinc
            }
            return responseItem
        }
        return nil
    }
}

public class QuestionForm : ACAbstractItem {
    
    public final var question  : String?
    public final var questions : [QuestionItem]
    public final var responses : [ResponseItem]
    public final var responseForm : ACResponseForm?
    public final let formID    : String
    public final var responseDate : Date?
    public final var answeredResponseOID : String? {
        didSet {
            answeredResponse = responses.filter{ $0.responseOID == answeredResponseOID }.first
        }
    }
    public var answeredResponse: ResponseItem?
    
    public init(oid: String, questions: [QuestionItem], responses: [ResponseItem], formID: String, order: UInt) {
        self.questions = questions
        self.responses = responses
        self.formID    = formID
        self.question  = questions.filter { $0.question.contains("Container") == false }.map{ $0.question }.joined(separator: "\n")
        super.init(oid: oid, responseOID: nil, order: order)
    }
    
    public class func create(from json: JSONDict) -> QuestionForm? {
        
        if let formOID = json["FormItemOID"] as? String,
        let order           = json["Order"] as? String,
            let formID          = json["ID"] as? String,
            let questionItemElements = json["Elements"] as? [JSONDict]
        {
            //Create QuestionItem objects
            let qItems = questionItemElements.map { QuestionItem.create(from: $0)! }
            let responseElement = questionItemElements.last!
            let responseItemElements = responseElement["Map"] as! [JSONDict]
            let responseItems = responseItemElements.map{ ResponseItem.create(from: $0)! }
            let questionForm = QuestionForm(oid: formOID, questions: qItems, responses: responseItems, formID: formID, order: UInt(order)!)
            if let responseForm    = ACResponseForm.create(from: responseElement) {
                questionForm.responseForm  = responseForm
            }
            if let loinc = json["LOINC_NUM"] as? String {
                questionForm.loinc = loinc
            }
            return questionForm
        }
        return nil
    }
    
}

public class ACBattery : ACAbstractItem {
    
    
    public final var title : String? = nil
    public final var forms : [ACForm]?
    
    public init(_ oid: String, _ title: String) {
        self.title = title
        super.init(oid: oid, responseOID: nil, order: nil)
    }
    
}

public class ACForm : ACAbstractItem {
    
    public final let title: String?
    public final var score: ACScore? = nil
    public final var questionForms : [QuestionForm]?
	public final var complete : Bool {
		get { return questionForms != nil }
	}
    
    public init(_oid : String, _title: String?, _loinc: String?) {
        self.title = _title
        super.init(oid: _oid, responseOID: nil, order: nil)
        self.loinc = _loinc

    }
    
    
    
    public func parse(from json: JSONDict) {
        //mainly for QuestionForms
        if let questionFormElements = json["Items"] as? [JSONDict] {
            let qForms = questionFormElements.map { QuestionForm.create(from: $0)! }
            self.questionForms = qForms
        }
    }
    
    public func getResponseItem(responseOID: String, forQuestionFormOID qOID: String) -> ResponseItem? {
        guard let questionForms = questionForms else {
            print("No questions in Form")
            return nil
        }
        
        let qForm = questionForms.filter{ $0.OID == qOID }.first
        qForm?.answeredResponseOID = responseOID
        return qForm?.responses.filter{ $0.responseOID == responseOID }.first
    }
    
    
    public func answeredQuestionsForms() -> [QuestionForm]? {
        guard let questionForms = questionForms else {
            return nil
        }
        return questionForms.filter { $0.answeredResponseOID != nil }
    }
    
}


public class SessionItem : ACAbstractItem {
    
    public final let expirationDate : Date
    public final let username       : String?
    public final let startDate      : Date
    public final var completionDate : Date?
    public final var completionDateString     : String?
    public var lastResponse : ResponseItem?
    public var score : ACScore?
    public var hasEnded : Bool {
        get {
            let date = Date()
            return (date > expirationDate || completionDate != nil)
        }
    }
    
    public init(oid: String, username: String?, expiration: Date) {
        self.username = username
        self.expirationDate = expiration
        self.startDate = Date()
        super.init(oid: oid, responseOID: nil, order: nil)
    }
    
    func description() -> String {
        return (" OID: \(self.OID)\n, User: \(self.username ?? "Nil")\n Expiration: \(self.expirationDate), finished: \(String(describing: self.completionDate))")
    }
    
    
}


public class ACResponseForm : ACAbstractItem {
    
    public let responseItems : [ResponseItem]
    
    public init(oid: String, responseItems: [ResponseItem]) {
        
        self.responseItems = responseItems
        super.init(oid: oid, responseOID: nil, order: nil)
    }
    
    class func create(from json: JSONDict) -> ACResponseForm? {
        
        if let responses = json["Map"] as? [JSONDict] {
            let responseItems = responses.map{ ResponseItem.create(from: $0)! }
            let responseForm = ACResponseForm(oid: json["ElementOID"] as! String, responseItems: responseItems)
            responseForm.loinc = json["LOINC_NUM"] as? String
            print(responseForm.listPropertiesWithValues())
            return responseForm
        }
        return nil
    }
    
    
}


public struct ACScore {
    
    public  let tscore : String
    private let stdError : String
    public  let standardError : String
    public  let username : String
    let formName : String
    
    init(from json :JSONDict) {
        let theta = json["Theta"] as! String
        self.stdError = json["StdError"] as! String
        username      = json["UID"] as! String
        formName      = json["Name"] as! String
        self.tscore = String(round((Double(theta)! * 10) + 50.0))
        self.standardError =  String(round(Double(stdError)! * 10))
    }
}

