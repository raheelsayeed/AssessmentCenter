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
    private var movingNextPage        = true
    
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
        super.init(task: task, taskRun: UUID(uuidString: sessionIdentifier))
    }
    
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.showsProgressInNavigationBar = false
        beginFirstQuestion()
    }
    
    private func beginFirstQuestion() {
        
        self.tsk.client.nextQ(form: self.tsk.form, responses: nil) { (questionForm, error, finished, score) in
            if let newQ = questionForm {
                let rule = ORKDirectStepNavigationRule(destinationStepIdentifier: newQ.formID)
                self.tsk.setNavigationRule(rule, forTriggerStepIdentifier: ACStep.introductionStep.rawValue)
            }
        }
        /*
        self.tsk.client.nextQuestion(session: self.tsk.session!, responseItem: nil) { [unowned self] (newQuestionForm, error, completion, completionDate) in
            if let newQuestionForm = newQuestionForm {
                let rule = ORKDirectStepNavigationRule.init(destinationStepIdentifier: newQuestionForm.formID)
                self.tsk.setNavigationRule(rule, forTriggerStepIdentifier: ACStep.introductionStep.rawValue)
            }
        }*/
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

		stepViewController.navigationItem.leftBarButtonItem = nil
        if let step = stepViewController.step {
            
            let btntitle : String
            switch step.identifier {
            case ACStep.conclusionStep.rawValue:
                btntitle = btnTitle_Conluded
                break
            case ACStep.introductionStep.rawValue:
                btntitle = btnTitle_BeginSession
                break
            default:
                btntitle = btnTitle_inSession
            }
            stepViewController.continueButtonTitle = btntitle
        }

        super.stepViewControllerWillAppear(stepViewController)
    }
}
