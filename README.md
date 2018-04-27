# AssessmentCenter

Swift framework for Patient Reported Outcome Measures (PRO-Measures). Computer Adaptive Test (backed by Item Response Theory) provided by [AssessmentCenter](http://www.assessmentcenter.net) at Northwestern University.


## ResearchKit

`AssessmentCenter` Framework module includes [`ResearchKit`](http://researchkit.org) as a submodule. AC by itself only utilizes its Survey module. Applications can potentially add other `ResearchKit` modules if required. 




## Getting Started

### Installation

```
$ git clone --recursive https://github.com/raheelsayeed/AssessmentCenter.git
```

1. Add `AssessmentCenter.xcodeproj` and `ResearchKit.xcodeproj` into the project directory of your app in Xcode. 
2. Build the Frameworks in Xcode.
3. Link and embed the `AssessmentCenter.framework` and `ResearchKit.framework` by selecting your app's target > **Build Phases** > **Link Binary with Libraries** and **Embed Frameworks**.

### Initialize by creating a `ACClient`

```swift
import AssessmentCenter


// initialize Assessment Center Client
let baseURLString = "<# https://www.assessmentcenter.net/ac_api/.. #>"
let accessId = "<# AccessIdentifier #>" 
let accessToken = "<# AccessToken #>"

let client = ACClient(baseURL: URL(string: baseURLString)!, accessIdentifier: accessId, token: accessToken)
```

### List all available instruments provided by the Assessment Center.
```swift
// Fetches a list of available of `ACForm` from Assessment Center
client.listForms { (list) in
	if let list = list {
		list.forEach{ print($0.title!) }
	}
}
```

###  Instrument Session

- `ACForm` is passed to `ACTaskViewController` a subclass of `ORKTaskViewController`
- Each response is sent to AssessmentCenter to get the next question.

```swift

// Initialise `ACForm` with OID.
// Alternatively, `client.listForms()`
let instrumentForm = ACForm(_oid: "<# AC Form OID #>", _title: "<# PROMIS Sleep #>", _loinc: "<# LOINC Code #>")

// Downloads complete instrument with questions and responses
// Complete instrument `ACForm` is passed to create a `ORKTaskViewController` (ResearchKit's QA Interface)


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
