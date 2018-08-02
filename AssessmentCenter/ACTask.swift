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

public class ACTask : ORKNavigableOrderedTask {
    
    public var session : SessionItem?
    let client  : ACClient
    public let form    : ACForm
    
    required public init(acform: ACForm, client: ACClient) {
        self.form = acform
        self.client = client
        var steps = acform.researchKit_steps()
        steps?.insert(ACTask.introductionStep(title: form.title, detail: nil), at: 0)
        steps?.append(ACTask.InstructionStep(identifier: ACStep.conclusionStep.rawValue))
        super.init(identifier: acform.OID, steps: steps)
    }
    
    class func introductionStep(title: String?, detail: String?) -> ORKInstructionStep {
        let i = ACTask.InstructionStep(identifier: ACStep.introductionStep.rawValue)
        i.title = title
        i.detailText = detail
        return i
    }
    
    class func InstructionStep(identifier: String) -> ORKInstructionStep {
        let instructionStep = ORKInstructionStep(identifier: identifier)
        return instructionStep
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func step(after step: ORKStep?, with result: ORKTaskResult) -> ORKStep? {
        
        guard let sourceStep = step else {
            return super.step(after:step, with: result)
        }
        
        if  let chosenResult = result.stepResult(forStepIdentifier: sourceStep.identifier),
            let answerResult = chosenResult.firstResult as? ORKChoiceQuestionResult,
            let resultIdentifier = answerResult.choiceAnswers?.first as? String {
            
            let responseOID = resultIdentifier.components(separatedBy: "+").first //as! String
            let responseItem = self.form.getResponseItem(responseOID: responseOID!, forQuestionFormOID: sourceStep.identifier)
            if responseItem != nil {
                let semaphore = DispatchSemaphore(value: 0)
                self.client.nextQuestion(session: self.session!, responseItem: responseItem, completion: { [unowned self] (newQuestionForm, error, completed, completionDate) in
                    let destinationStepID = (completed) ? ACStep.conclusionStep.rawValue : newQuestionForm!.OID
                    if completed {
                        self.client.score(session: self.session!, completion: { [unowned self] (acScore, error) in
                            if let acScore = acScore {
                                self.session?.score = acScore
                                self.form.score = acScore 
                                self.configureConclusionFor(step: self.step(withIdentifier: ACStep.conclusionStep.rawValue)!, with: acScore)
                            }
                            else {
                                print(error as Any)
                                print("Cannot get score")
                            }
                            let rule = ORKDirectStepNavigationRule(destinationStepIdentifier: destinationStepID)
                            self.setNavigationRule(rule, forTriggerStepIdentifier: sourceStep.identifier)
                            semaphore.signal()
                        })
                    }
                    else {
                        let rule = ORKDirectStepNavigationRule(destinationStepIdentifier: destinationStepID)
                        self.setNavigationRule(rule, forTriggerStepIdentifier: sourceStep.identifier)
                        semaphore.signal()
                    }
             
                })
                semaphore.wait()
            }
        }
        return super.step(after: step, with: result)
    }
    
    
    func configureConclusionFor(step: ORKStep, with score: ACScore) {
        step.title = "Completed"
        step.text  =
        """
        T-Score: \(score.tscore)
        StdError: \(score.standardError)
        """
    }
}
