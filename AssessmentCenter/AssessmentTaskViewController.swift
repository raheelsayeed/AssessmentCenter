//
//  AssessmentTaskViewController.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 14/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

import Foundation
import ResearchKit


public class ACTaskViewController : ORKTaskViewController {
    
    let btnTitle_inSession            =   "Continue"
    let btnTitle_Conluded             =   "Done"
    let btnTitle_BeginSession         =   "Begin"
    let sessionIdentifier: String
    public weak var instructionsDelegate    : ACTaskViewControllerInstructionsDelegate? = nil
    public weak var taskDelegate            : ACTaskViewControllerDelegate? = nil
    private var movingNextPage               = true
    
    public var session : SessionItem? {
        get { return self.tsk.session }
    }
    
    private var tsk : ACTask {
        get { return self.task as! ACTask }
    }
    public var score: ACScore? {
        get {return self.tsk.session?.score }
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
        movingNextPage = (direction == .forward) ? true : false
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
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let navController = self.navigationController, navController.viewControllers.count > 1 {
            if navController.topViewController == self {
                navController.popViewController(animated: flag)
            }
        }
        super.dismiss(animated: flag, completion: completion)
    }
    
    
}

extension ACTaskViewController : ORKTaskViewControllerDelegate {
    
    
    func configureConclusionFor(step: ORKStep, with score: ACScore) {
        step.title = "Completed"
        step.text  =
        """
        T-Score: \(score.tscore)
        StdError: \(score.standardError)
        """
    }
    
    public func taskViewController(_ taskViewController: ORKTaskViewController, didFinishWith reason: ORKTaskViewControllerFinishReason, error: Error?) {
        
        
        self.taskDelegate?.assessmentViewController(self, didFinishWith: .success, error: nil, tscore: 0.0, stderror: 0.0, session: self.tsk.session!)
        self.dismiss(animated: true) {
            self.taskDelegate?.didDismissACTaskViewController()
        }
    }
    
    
    
    public func taskViewController(_ taskViewController: ORKTaskViewController, viewControllerFor step: ORKStep) -> ORKStepViewController? {
        
        if step.identifier == ACStep.conclusionStep.rawValue {
            let semaphore = DispatchSemaphore(value: 0)
            self.tsk.client.score(session: self.tsk.session!, completion: { [unowned self] (acScore, error) in
                if let acScore = acScore {
//                    self.score = acScore
                    self.tsk.session?.score = acScore
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
           
            step.title = self.tsk.form.title
            step.text  = instructionsDelegate?.instructionsFor(self)
            
        }
     
        return nil
    }
}
public enum ACTaskFinishReason : Int {
    
    case success
    case fail
}

public protocol ACTaskViewControllerDelegate : class  {
    
    func assessmentViewController(_ taskViewController: ACTaskViewController, didFinishWith reason: ACTaskFinishReason, error : Error?, tscore: Double?, stderror: Double?, session: SessionItem)
    
    func didDismissACTaskViewController()
}
public protocol ACTaskViewControllerInstructionsDelegate : class  {
    
    func completionMessageFor(_ taskViewController: ACTaskViewController) -> String?
    
    func instructionsFor(_ taskViewController: ACTaskViewController) -> String?
}
