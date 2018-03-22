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
                [ "system" : "http://loinc.org", "code" : loinc]
            ]
        } else {
            fhirFORM["code"] = [
                [ "system" : "http://assessmentcenter.net", "code" : OID]
            ]
        }
        
        
        let qForms = (answeredOnly) ? self.answeredQuestionsForms()! : questionForms
        
		var questionitems = qForms.map { $0.as_FHIR() }
		questionitems.append([
			"linkId" : "tscore",
			"readOnly" : true,
			"type"     : "string"
			])
		questionitems.append([
			"linkId" : "stderror",
			"readOnly" : true,
			"type"     : "string"
			])
		
        fhirFORM["item"] = questionitems
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
    
	public func as_FHIRQuestionnaireResponse(with score: ACScore? = nil) -> JSONType? {
        
        guard let answeredQuestionsForms = answeredQuestionsForms()  else {
            return nil
        }
        var qr = JSONType()
        if var q = as_FHIRQuestionnaire() {
            let iden = loinc ?? OID
			if loinc == nil {
				qr["identifier"] = ["system" : "http://assessmentcenter.net", "value" : OID]
			}
			else {
				qr["identifier"] = ["system" : "http://loinc.org", "value" : loinc]
			}
            q["id"] = iden
            qr["questionnaire"] = ["reference" : "#\(iden)"]
            qr["contained"] = [q]
        }
		
        qr["resourceType"] = "QuestionnaireResponse"
        qr["status"]       = "completed"
		var answeredQuestions = answeredQuestionsForms.map({ (qForm) -> JSONType in
            let answerItem = qForm.answeredResponse!
            let coding  : JSONType
            if let loinc = answerItem.loinc {
                coding  = ["code" : loinc, "display" : answerItem.text, "system" : "http://loinc.org"]
            } else {
                coding  = ["code" : answerItem.value, "display" : answerItem.text, "system" : "http://assessmentcenter.net"]
            }
            return [ "linkId" : qForm.formID,
                     "text"   : qForm.question!,
                     "answer" : [["valueCoding" : coding]]
                ]
        })
		
		if let score = score {
			
			answeredQuestions.append(
				[
					"linkId" : "tscore",
					"text"   : "T-Score",
					"answer" : [["valueString" : score.tscore]]
				]
			)
			answeredQuestions.append(
				[
					"linkId" : "stderror",
					"text"   : "Standard Error",
					"answer" : [["valueString" : score.standardError]]
				]
			)
		}
		
		qr["item"] = answeredQuestions
		
		
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
            "code"          : responseOID!,
            "display"       : text,
            "id"            : responseOID!
        ]
        return code
    }
}
