//
//  ACModel+ResearchKit.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 14/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

import Foundation
import ResearchKit

extension ACForm {
    
    public func researchKit_steps() -> [ORKStep]? {
        
        guard let questionForms = questionForms else {
            print("No Questions to create Steps")
            return nil
        }
        return questionForms.map { $0.researchKit_ORKQuestionStep()! }
    }
}

extension QuestionForm {
    public func researchKit_ORKQuestionStep() -> ORKQuestionStep? {
        
        guard let question = question else {
            print("No Question Found")
            return nil
        }
        let choices : [ORKTextChoice] = responses.map {
            ORKTextChoice(text: $0.text, detailText: nil, value:"\($0.responseOID!)+\($0.value)" as NSCoding & NSCopying & NSObjectProtocol, exclusive: false)
        }
        let questionStep = ORKQuestionStep(identifier: self.OID)
        questionStep.answerFormat = ORKTextChoiceAnswerFormat(style: ORKChoiceAnswerStyle.singleChoice, textChoices: choices)
        questionStep.title = question
        return questionStep
    }
}
