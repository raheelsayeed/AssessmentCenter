//
//  ACClient.swift
//  AssessmentCenter
//
//  Created by Raheel Sayeed on 13/02/18.
//  Copyright © 2018 Boston Children's Hospital. All rights reserved.
//

/*
 ? UTC, CST Dates? Difference?
 ? Can Participant/<> API sent back the FormID in Question?
 ? requestCompletion Handlers are not on the Main Thread
 - TODO:
 - Error Codes (AC Status)
 - Logging
*/

import Foundation

public typealias JSONDict = [String: Any]
typealias RequestHeaders = [String : String]



open class ACClient {
    
    
    static let keyAllForms = "Forms/.json"
    static let keyForm     = "Form"
    
    private final let accessIdentifier : String
    private final let accessToken : String
    public  final let baseURL : URL
    
    public required init(baseURL base: URL, accessIdentifier: String, token: String) {
        self.accessIdentifier = accessIdentifier
        self.accessToken = token
        if base.absoluteString.last != "/" {
            self.baseURL = base.appendingPathComponent("/")
        } else {
            self.baseURL = base
        }
    }
    
    
    public convenience init(credentials: [String:String]) {
        let baseURLString = credentials["baseurl"]!
        let accessID      = credentials["accessidentifier"]!
        let accessToken   = credentials["accesstoken"]!
        self.init(baseURL: URL(string: baseURLString)!, accessIdentifier: accessID, token: accessToken)
    }
    
    private var authEncoded : String {
        get {
            return "\(accessIdentifier):\(accessToken)".base64encoded()
        }
    }
    private func defaultRequest(path:String, headers: RequestHeaders?)-> URLRequest {
        
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("Basic \(authEncoded)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let headers = headers {
            var headerString = headers.reduce(into: String(), { (resultstring, arg) in
                let (key, value) = arg
                resultstring += "\(key)=\(value.URLEncoded())&"
            })
            headerString.removeLast(1)
            request.httpBody = headerString.data(using: .utf8)
        }
        return request

    }
    private func performRequest(path : String, headers: RequestHeaders?, completion: @escaping (_ response: JSONDict?, _ error: Error?) -> Void) {
        
        if path.isEmpty {
            print("No API Endpoint")
            return
        }
        print("%%%%%%%%%%%%%%%%%%%%%%%%%%%")
        print("Requesting.. \(path)")
        
        // ::: Should all operations in Queue be cancelled?
        let request = defaultRequest(path: path, headers: headers)
        
        let dataTask = URLSession.shared.dataTask(with: request) { (data, urlresponse, rerror) in
            
            if let data = data {
                do {
                    let decodedJSON = try JSONSerialization.jsonObject(with: data, options: [])
                    if let decodedJSON = decodedJSON as? JSONDict {
                        completion(decodedJSON, nil)
                    }
                }
                catch {
                    print (error.localizedDescription)
                    completion(nil, error)
                }
            } else {
                print (rerror?.localizedDescription ?? "Error, data was nil")
                completion(nil, rerror)
            }
        }
        
        dataTask.resume()
    }
    
    
    public func listForms(loinc: Bool = true, completion : ((_ forms: [ACForm]?)->Void)?) {
        let header = (loinc) ? ["CODING_SYSTEM" : "LOINC"] : nil

        performRequest(path: ACClient.keyAllForms, headers: header) { (responseJSON, error) in
            
            if let responseJSON = responseJSON, let list = responseJSON["Form"] as? [[String:String]] {
                print(list)
                let acForms : [ACForm] = list.map {
                    ACForm(_oid: $0["OID"]!, _title: $0["Name"]!, _loinc: $0["LOINC_NUM"])
                }
                completion?(acForms)
            }
            
            if let error = error {
                print(error.localizedDescription)
            }
            completion?(nil)
        }
    }
    
    public func form(acform: ACForm, completion : (( _ form: ACForm? )-> Void)?) {
        let formEndpoint = "Forms/\(acform.OID).json"
        performRequest(path: formEndpoint, headers: nil) { (json, error) in
            if let json = json {
                acform.parse(from: json)
                completion?(acform)
            }
        }
    }
    
    public func form(OID: String, completion: ((_ form: ACForm?)->Void)?) {
        let acform = ACForm(_oid: OID, _title: nil, _loinc: nil)
        self.form(acform: acform, completion: completion)
        
    }
    
    
    public func beginSession(with form: ACForm, username: String?, expiration: Date?, completion : ((_ newSession : SessionItem?) -> Void)?) {
        let endpoint = "Assessments/\(form.OID).json"
        //::: No custom expiration support yet.
        let requestHeader = ["UID" : username] as? RequestHeaders
        performRequest(path: endpoint, headers: requestHeader) { (json, error) in
            
            if let json = json, let oid = json["OID"] as? String {
                
                let expirationDate = Date.dateFormatter_UTC.date(from: json["Expiration"] as! String)
                let session = SessionItem(oid: oid, username: json["UID"] as? String, expiration: expirationDate!)
                completion?(session)
            }
            
        }
    }
    
    public func nextQuestion(sessionOID: String, responseItemOID: String?, responseValue: String?, completion : ((_ newQuestionForm : QuestionForm?, _ error: Error?, _ concluded: Bool, _ completionDate: Date?)->Void)?) {
        let endpoint = "Participants/\(sessionOID).json"
        let requestHeader = ["ItemResponseOID": responseItemOID,
                             "Response" : responseValue] as? RequestHeaders
        self.performRequest(path: endpoint, headers: requestHeader) { (json, rerror) in
            
            if let json = json, let formJSON = json["Items"] as? [JSONDict] {
                if let dateFinished = json["DateFinished"] as? String, !dateFinished.isEmpty {
                    let conclusionDate = Date.dateFormatter_CST.date(from: dateFinished)
                    completion?(nil, nil, true, conclusionDate)
                    return
                }
                let qForm = QuestionForm.create(from: formJSON.first! )
                completion?(qForm, nil, false, nil)
            }
            else {
                completion?(nil, nil, false, nil)
            }
        }
    }
    public func nextQuestion(session: SessionItem, responseItem: ResponseItem?, completion: ((_ newQuestionForm : QuestionForm?, _ error: Error?, _ concluded: Bool, _ completionDate: Date?)->Void)?) {
        nextQuestion(sessionOID: session.OID, responseItemOID: responseItem?.responseOID, responseValue: responseItem?.value, completion: completion)
        
    }
    
    public func score(session: SessionItem, completion: ((_ score : ACScore?, _ error : Error?)->Void)?) {
        let endpoint = "Results/\(session.OID).json"
        performRequest(path: endpoint, headers: nil) { (json, error) in
            if let json = json {
                let score = ACScore(from: json)
                completion?(score, nil)
            }
            else {
                print("Could Not Get the score")
                completion?(nil, nil)
            }
        }
    }
    
    
}



