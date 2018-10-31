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
        steps?.append(ORKCompletionStep(identifier: ACStep.conclusionStep.rawValue))
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
    
    func resultsBody(for result: ORKTaskResult) -> [String : String]? {
        if let results = result.results?.filter({$0.identifier != ACStep.introductionStep.rawValue && $0.identifier != ACStep.conclusionStep.rawValue }).map({ $0 as! ORKStepResult }), results.count > 0 {
            
            var res = [String:String]()
            for result in results {
                let stepIdentifier = result.identifier
                let choiceResult = result.results?.first as! ORKChoiceQuestionResult
                let answer = choiceResult.choiceAnswers!.first as! String
                let text = answer.components(separatedBy: "+").last!
                res[stepIdentifier] = text
                if result == results.last {
                    form.setResponseItem(responseText: text, forQuestionID: stepIdentifier)
                }
            }
            return res
        }
        return nil
    }
    
    override public func step(after step: ORKStep?, with result: ORKTaskResult) -> ORKStep? {
        
        guard let sourceStep = step, sourceStep.identifier != ACStep.conclusionStep.rawValue else {
            return super.step(after:step, with: result)
        }
        let results = resultsBody(for: result)
        let semaphore = DispatchSemaphore(value: 0)
        client.nextQ(form: form, responses: results) { (questionForm, error, finished, score) in
            if let q = questionForm {
                let rule = ORKDirectStepNavigationRule(destinationStepIdentifier: q.formID)
                self.setNavigationRule(rule, forTriggerStepIdentifier: sourceStep.identifier)
            }
            else if let score = score {
                let rule = ORKDirectStepNavigationRule(destinationStepIdentifier: ACStep.conclusionStep.rawValue)
                self.form.score = score
                self.configureConclusionFor(step: self.step(withIdentifier: ACStep.conclusionStep.rawValue)!, with: score)
                self.setNavigationRule(rule, forTriggerStepIdentifier: sourceStep.identifier)
            }
            semaphore.signal()
        }
        semaphore.wait()

        //LEGACY: Sessions-API
        /*
        if  let chosenResult = result.stepResult(forStepIdentifier: sourceStep.identifier),
            let answerResult = chosenResult.firstResult as? ORKChoiceQuestionResult,
            let resultIdentifier = answerResult.choiceAnswers?.first as? String {
            
            let responseOID = resultIdentifier.components(separatedBy: "+").first //as! String
            let responseItem = form.getResponseItem(responseOID: responseOID!, forQuestionID: sourceStep.identifier)
            let responseItem = self.form.getResponseItem(responseOID: responseOID!, forQuestionFormOID: sourceStep.identifier)
            if responseItem != nil {
                let semaphore = DispatchSemaphore(value: 0)
                self.client.nextQuestion(session: self.session!, responseItem: responseItem, completion: { [unowned self] (newQuestionForm, error, completed, completionDate) in
                    let destinationStepID = (completed) ? ACStep.conclusionStep.rawValue : newQuestionForm!.formID
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
            }*/
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
