//
//  AssessmentTaskViewController.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 14/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

import Foundation
import ResearchKit


public class AssessmentViewController : ORKTaskViewController {
    
    let btnTitle_inSession            =   "Continue"
    let btnTitle_Conluded             =   "Done"
    let btnTitle_BeginSession         =   "Begin"
    let sessionIdentifier: String
    weak var instructionsDelegate    : AssessmentViewControllerInstructionsDelegate? = nil
    weak var taskDelegate            : AssessmentViewControllerDelegate? = nil
    var movingNextPage               = true
    var score                        : ACScore?
    var tsk : ACTask {
        get {
            return self.task as! ACTask
        }
    }
    
    required public init(acform: ACForm, client: ACClient, sessionIdentifier: String) {
        self.sessionIdentifier = sessionIdentifier
        let task = ACTask(acform: acform, client: client)
        super.init(task: task, taskRun: nil)
        self.delegate = self
    }
    
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.showsProgressInNavigationBar = false
        self.tsk.client.beginSession(with: self.tsk.form, username: sessionIdentifier, expiration: nil) { [unowned self] (sessionItem) in
            if let sessionItem = sessionItem {
                self.tsk.session = sessionItem
                self.beginFirstQuestion()
            }
        }
    }
    
    private func beginFirstQuestion() {
        self.tsk.client.nextQuestion(session: self.tsk.session!, responseItem: nil) { [unowned self] (newQuestionForm, error, completion, completionDate) in
            if let newQuestionForm = newQuestionForm {
                let rule = ORKDirectStepNavigationRule.init(destinationStepIdentifier: newQuestionForm.OID)
                self.tsk.setNavigationRule(rule, forTriggerStepIdentifier: ACStep.introductionStep.rawValue)
            }
        }
    }
    
    // MARK: Step Delegate Methods
    // A workaround for ResearchKit to support External API Calls between steps.
    
    public override func stepViewControllerResultDidChange(_ stepViewController: ORKStepViewController) {
        movingNextPage = false
    }
    
    public override func stepViewController(_ stepViewController: ORKStepViewController, didFinishWith direction: ORKStepViewControllerNavigationDirection) {
        movingNextPage = true
        super.stepViewController(stepViewController, didFinishWith: direction)
    }
    
    public override func stepViewControllerHasNextStep(_ stepViewController: ORKStepViewController) -> Bool {
        return movingNextPage
    }
    
    
    public override func stepViewControllerWillAppear(_ stepViewController: ORKStepViewController) {
        
        if stepViewController.step?.identifier == ACStep.conclusionStep.rawValue {
            stepViewController.continueButtonTitle = btnTitle_Conluded
            stepViewController.title = "SESSION TOKEN: \(self.tsk.session!.OID)"
        }
        else if stepViewController.step?.identifier == ACStep.introductionStep.rawValue {
            stepViewController.continueButtonTitle = btnTitle_BeginSession
            stepViewController.title = self.tsk.form.title
            
        }
        else {
            stepViewController.continueButtonTitle = btnTitle_inSession
            stepViewController.title = "SESSION TOKEN: \(self.tsk.session!.OID)"
        }
        super.stepViewControllerWillAppear(stepViewController)
    }
    
    
}

extension AssessmentViewController : ORKTaskViewControllerDelegate {
    
    
    func configureConclusionFor(step: ORKStep, with score: ACScore) {
        step.title = "Completed"
        step.text  =
        """
        T-Score: \(score.tscore)
        StdError: \(score.standardError)
        """
    }
    
    public func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        
        if let taskDelegate = taskDelegate {
            
            if reason == .completed {
                taskDelegate.assessmentViewController(self, didFinishWith: .success, error: nil, tscore: Double(score!.tscore), stderror: Double(score!.standardError), session: self.tsk.session!)
            }
            
            if taskDelegate.canDismissTaskVC(self) {
                self.dismiss(animated: true, completion: nil)
            }
        }
        else {
            
            self.dismiss(animated: true, completion: nil)
        }
        
    }
    
    public func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        
        if step.identifier == ACStep.conclusionStep.rawValue {
            let semaphore = DispatchSemaphore(value: 0)
            self.tsk.client.score(session: self.tsk.session!, completion: { [unowned self] (acScore, error) in
                if let acScore = acScore {
                    self.score = acScore
                    self.configureConclusionFor(step: step, with: acScore)
                }
                else {
                    print(error as Any)
                    print("Cannot get score")
                }
                semaphore.signal()
            })
            semaphore.wait()
        }
        else if step.identifier == ACStep.introductionStep.rawValue {
            
            if let instructionsDelegate = instructionsDelegate {
                
                step.text = instructionsDelegate.sessionInstructionsForTaskVC(self)
                
            }
            
        }
     
        return nil
    }
}
public enum AssessementFinishReason : Int {
    
    case success
    case fail
}

protocol AssessmentViewControllerDelegate : class  {
    
    func assessmentViewController(_ assessmentViewController: AssessmentViewController, didFinishWith reason: AssessementFinishReason, error : Error?, tscore: Double?, stderror: Double?, session: SessionItem)
    
    func canDismissTaskVC(_ canDismissVC:AssessmentViewController) -> Bool
}
protocol AssessmentViewControllerInstructionsDelegate : class  {
    
    func sessionCompletionMessageForTaskVC(_ sessionCompletionMessageForTaskVC: AssessmentViewController) -> String?
    
    func sessionInstructionsForTaskVC(_ sessionInstructionsForTaskVC: AssessmentViewController) -> String?
}