//
//  ACModel+FHIR.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 27/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

import Foundation

public typealias JSONType = [String : Any]

extension ACForm {
    
    public func as_FHIRQuestionnaire(answeredOnly: Bool = true) -> JSONType? {
        
        guard let title = title, let questionForms = questionForms else {
            print("ACForm not complete")
            return nil
        }
        
        var fhirFORM = JSONType()
        fhirFORM["title"] = title
        fhirFORM["subjectType"] = ["Patient"]
        fhirFORM["status"] = "active"
        fhirFORM["resourceType"] = "Questionnaire"
        fhirFORM["publisher"] = "PROMIS Health Organization and PROMIS Cooperative Group"
        
        if let loinc = loinc {
            fhirFORM["code"] = [
                [ "system" : "http://loin.org", "code" : loinc]
            ]
        } else {
            fhirFORM["code"] = [
                [ "system" : "http://assessmentcenter.net", "code" : OID]
            ]
        }
        
        
        let qForms = (answeredOnly) ? self.answeredQuestionsForms()! : questionForms
        
        
        fhirFORM["item"] = qForms.map  { $0.as_FHIR() }
        let responseForms = qForms.map { $0.responseForm! }
        
        // Contained Answer ValueSets
        let uniqueChoiceValueSetsIds  =  Set(responseForms.map{ $0.fhir_Reference })
        print(uniqueChoiceValueSetsIds)
        
        let vs = uniqueChoiceValueSetsIds.map { (referenceId) -> JSONType in
            return responseForms.filter { $0.fhir_Reference == referenceId }.first!.as_FHIR()!
        }
        fhirFORM["contained"] = vs
        return fhirFORM
    }
    
    public func as_FHIRQuestionnaireResponse() -> JSONType? {
        
        guard let answeredQuestionsForms = answeredQuestionsForms()  else {
            return nil
        }
        
        
        
        var qr = JSONType()
        qr["resourceType"] = "QuestionnaireResponse"
        qr["status"]       = "completed"
        // Requires Patient
        qr["item"]         = answeredQuestionsForms.map({ (qForm) -> JSONType in
            
            let answerItem = qForm.answeredResponse!
            return [ "linkId" : qForm.formID,
                     "text"   : qForm.question!,
                     "answer" : [
                        [
                        "valueCoding" : [
                                "code" : answerItem.value,
                                "display" : answerItem.text,
                                "system"  : "http://assessmentcenter.net"
                            ]
                        ]
                        ]
                ]
        })
        return qr
    }
}

extension QuestionForm {
    
    public func as_FHIR() -> JSONType? {

        
        var questionnaireItem = JSONType()
        if let loinc = loinc {
            questionnaireItem["code"] = [
                [
                    "code" : loinc,
                    "system" : "http://loinc.org"
                ]
            ]
        }
        questionnaireItem["text"] = self.question
        questionnaireItem["type"] = "choice"
        questionnaireItem["linkId"] = self.formID
        questionnaireItem["options"] = ["reference" : "#\(self.responseForm!.fhir_Reference)"]
        
        return questionnaireItem
        
    }
}




extension ACResponseForm {
    
    public var fhir_Reference : String {
        get {
            if let loinc = loinc { return loinc }
            else { return OID }
        }
    }
    
    public func as_FHIR() -> JSONType? {
        
        var responseValueSet = JSONType()
        responseValueSet["id"] = fhir_Reference
        responseValueSet["resourceType"] = "ValueSet"
        responseValueSet["status"] = "active"
        // name?
        let codableConcept = responseItems.map { $0.as_FHIR() }
        let include = [
            ["concept" : codableConcept,
             "system"  : "http://assesssmentcenter.net"]
            ]
        responseValueSet["compose"] = ["include" : include]
        return responseValueSet
    }
    
}
extension ResponseItem {
    
    public func as_FHIR() -> JSONType? {
        
        let code : JSONType = [
            "code"          : loinc ?? responseOID!,
            "display"       : text,
            "id"            : responseOID!
        ]
        
        return code
        
    }
}
