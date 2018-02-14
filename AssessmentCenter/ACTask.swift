//
//  ACTask.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 14/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

import Foundation
import ResearchKit

public enum ACStep : String {
    
    case introductionStep
    case conclusionStep
}

class ACTask : ORKNavigableOrderedTask {
    
    var session : SessionItem?
    let client  : ACClient
    let form    : ACForm
    
    required init(acform: ACForm, client: ACClient) {
        self.form = acform
        self.client = client
        var steps = acform.researchKit_steps()
        steps?.insert(ACTask.instructionStep(identifier: ACStep.introductionStep.rawValue), at: 0)
        steps?.append(ACTask.instructionStep(identifier: ACStep.conclusionStep.rawValue))
        super.init(identifier: acform.OID, steps: steps)
    }
    
    class func instructionStep(identifier: String) -> ORKInstructionStep {
        let instructionStep = ORKInstructionStep.init(identifier: identifier)
        return instructionStep
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func step(after step: ORKStep?, with result: ORKTaskResult) -> ORKStep? {
        
        guard let sourceStep = step else {
            return super.step(after:step, with: result)
        }
        
        if let chosenResult = result.stepResult(forStepIdentifier: sourceStep.identifier),
            let answerResult = chosenResult.firstResult as? ORKChoiceQuestionResult,
        let resultIdentifier = answerResult.choiceAnswers?.first as? String{
            
            let responseOID = resultIdentifier.components(separatedBy: "+").first //as! String
            let responseItem = self.form.getResponseItem(responseOID: responseOID!, forQuestionFormOID: sourceStep.identifier)
            if responseItem != nil {
                let semaphore = DispatchSemaphore(value: 0)
                self.client.nextQuestion(session: self.session!, responseItem: responseItem, completion: { (newQuestionForm, error, completed, completionDate) in
                    let destinationStepID = (completed) ? ACStep.conclusionStep.rawValue : newQuestionForm!.OID
                    let rule = ORKDirectStepNavigationRule(destinationStepIdentifier: destinationStepID)
                    self.setNavigationRule(rule, forTriggerStepIdentifier: sourceStep.identifier)
                    semaphore.signal()
                })
                semaphore.wait()
            }
        }
        return super.step(after: step, with: result)
    }
}
