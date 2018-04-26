# AssessmentCenter

Swift framework for Patient Reported Outcome Measures (PRO-Measures). Computer Adaptive Test (backed by Item Response Theory) provided by [AssessmentCenter](http://www.assessmentcenter.net) at Northwestern University.


## ResearchKit

`AssessmentCenter` Framework module includes [`ResearchKit`](http://researchkit.org) as a submodule. AC by itself only utilizes its Survey module. Applications can potentially add other `ResearchKit` modules if required. 


## Getting Started

```swift
import AssessmentCenter


// initialise Assessment Center Client
let baseURLString = "<# https://www.assessmentcenter.net/ac_api/.. #>"
let accessId = "<# AccessIdentifier #>" 
let accessToken = "<# AccessToken #>"

let client = ACClient(baseURL: URL(string: baseURLString)!, accessIdentifier: accessId, token: accessToken)


// List All Measures from Assessment Center
client.listForms { (list) in
	if let list = list {
		list.forEach{ print($0.title!) }
	}
}


// Begin Measure
let form = ACForm(_oid: "<# AC Form OID #>", _title: "<# PROMIS Sleep #>", _loinc: "<# Loinc code #>)
client.form(acform: form, completion: { [unowned self] (completeForm) in 
    DispatchQueue.main.sync {
        if let completeForm = completeForm {
            // ACTaskViewController is a subclass of ORKTaskViewController (ResearchKit)
            let taskViewController = ACTaskViewController(acform: completeForm, client: client, sessionIdentifier: "Neuro-Clinic-testing")
            self.present(taskViewController, animated: true, completion: nil)
       }
   }
}
```
