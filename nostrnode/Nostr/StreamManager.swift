//
//  StreamManager.swift
//  nostrnode
//
//  Created by Peter Denton on 3/28/23.
//

import Foundation

final class StreamManager: NSObject {
        
    static let shared = StreamManager()
    var webSocket: URLSessionWebSocketTask?
    var opened = false
    var eoseReceivedBlock: (((Bool)) -> Void)?
    var errorReceivedBlock: (((String)) -> Void)?
    var pongReceivedBlock: (((Bool)) -> Void)?
    var onDoneBlock: (((response: Any?, errorDesc: String?)) -> Void)?
    let subId = Crypto.randomKey
    var connected = false
    var timer = Timer()
    
    
    private override init() {
    }
    
    
    func receive() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard let webSocket = self.webSocket else { print("websocket is nil"); return }
            webSocket.receive(completionHandler: { [weak self] result in
                guard let self = self else { return }
                self.timer.invalidate()
                switch result {
                case .success(let message):
                    self.processMessage(message: message)
                case .failure(let error):
                    print("Error Receiving \(error)")
                }
                self.receive()
            })
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: workItem)
    }
    
    
    private func processMessage(message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let strMessgae):
            let data = strMessgae.data(using: .utf8)!
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? NSArray
                {
                    #if DEBUG
                    print("received: \(strMessgae)")
                    #endif
                    switch jsonArray[0] as? String {
                    case "EOSE":
                        parseEose(arr: jsonArray)
                    case "EVENT":
                        parseEventDict(arr: jsonArray)
                    case "OK":
                        onDoneBlock!((nil, jsonArray[3] as? String))
                    case "NOTICE":
                        guard let noticeDesc = jsonArray[1] as? String else { return }
                        errorReceivedBlock!(noticeDesc)
                    default:
                        break
                    }
                }
            } catch let error as NSError {
                print(error)
            }
        default:
            break
        }
    }
    
    
    private func parseEose(arr: NSArray) {
        guard let recievedSubId = arr[1] as? String else { print("subid not recieved"); return }
        guard self.subId == recievedSubId else { print("subid does not match"); return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connected = true
            self.eoseReceivedBlock!(true)
        }
    }
    
    
    private func parseEventDict(arr: NSArray) {
        if let dict = arr[2] as? [String:Any], let created_at = dict["created_at"] as? Int {
            let now = NSDate().timeIntervalSince1970
            let diff = (now - TimeInterval(created_at))
            guard diff < 5.0 else { print("diff > 5, ignoring."); return }
            guard let ev = self.parseEvent(event: dict) else {
                self.onDoneBlock!((nil,"Nostr event parsing failed..."))
                #if DEBUG
                print("event parsing failed")
                #endif
                return
            }
            
            parseValidReceivedContent(content: ev.content) { [weak self] (command, port, requestId, httpMethod, param, wallet) in
                guard let self = self, let command = command, let port = port, let requestId = requestId else { print("Ignoring invalid event."); return }
                self.forwardRequest(command: command, port: port, requestId: requestId, httpMethod: httpMethod, param: param, wallet: wallet)
            }
        }
    }
    
    private func forwardRequest(command:String, port:Int, requestId: String, httpMethod: String?, param: [String:Any]?, wallet: String?) {
        switch port {
        case 8332, 18332, 18443, 38332:
            DataManager.retrieve { creds in
                guard let creds = creds else { return }
                let encryptionWords = creds["encryption_words"] as? String ?? ""
                let rpcUser = creds["btc_rpcuser"] as? String ?? ""
                let rpcPass = creds["btc_rpcpass"] as? String ?? ""
                
                BitcoinCoreRPC.shared.btcRPC(method: command, port: "\(port)", wallet: wallet, param: param ?? [:], requestId: requestId, rpcpass: rpcPass, rpcuser: rpcUser) { [weak self] (response, errorDesc) in
                    guard let self = self else { return }
                    let dictToSend:[String:Any] = [
                        "request_id": requestId,
                        "response": response as Any,
                        "error_desc": errorDesc as Any
                    ]
                    guard let jsonData = self.jsonFromDict(dict: dictToSend) else { return }
                    let encryptedContent = Crypto.encryptNostr(jsonData, encryptionWords)!.base64EncodedString()
                    self.writeEvent(content: encryptedContent)
                }
            }
            
        default:
            break
        }
    }
    
    private func jsonFromDict(dict: [String:Any]) -> Data? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return nil
        }
        return jsonData
    }
    
    
    private func writeReqEvent() {
        DataManager.retrieve { [weak self] creds in
            guard let self = self, let creds = creds else { return }
            let subscriptionKey = creds["nostr_subscription"] as? String ?? ""
            let filter:NostrFilter = NostrFilter.filter_authors(["\(subscriptionKey.dropFirst(2))"])
            let encoder = JSONEncoder()
            var req = "[\"REQ\",\"\(self.subId)\","
            guard let filter_json = try? encoder.encode(filter) else {
                #if DEBUG
                print("converting to jsonData failing...")
                #endif
                return
            }
            let filter_json_str = String(decoding: filter_json, as: UTF8.self)
            req += filter_json_str
            req += "]"
            print("req: \(req)")
            self.sendMsg(string: req)
        }
    }
    
    
    func writeEvent(content: String) {
        DataManager.retrieve { [weak self] creds in
            guard let self = self, let creds = creds else { return }
            
            let pubkey = creds["nostr_pubkey"] as? String ?? ""
            let privkey = creds["nostr_privkey"] as? String ?? ""
            
            let ev = NostrEvent(content: content,
                                pubkey: "\(pubkey.dropFirst(2))",
                                kind: NostrKind.ephemeral.rawValue,
                                tags: [])
            ev.calculate_id()
            ev.sign(privkey: privkey)
            guard !ev.too_big else {
                self.onDoneBlock!((nil, "Nostr event is too big to send..."))
                #if DEBUG
                print("event too big: \(content.count)")
                #endif
                return
            }
            guard ev.validity == .ok else {
                self.onDoneBlock!((nil, "Nostr event is invalid!"))
                #if DEBUG
                print("event invalid")
                #endif
                return
            }
            let encoder = JSONEncoder()
            let event_data = try! encoder.encode(ev)
            let event = String(decoding: event_data, as: UTF8.self)
            let encoded = "[\"EVENT\",\(event)]"
            self.sendMsg(string: encoded)
        }
    }
    
    
    private func sendMsg(string: String) {
        let msg:URLSessionWebSocketTask.Message = .string(string)
        guard let ws = self.webSocket else { print("no websocket"); return }
        ws.send(msg, completionHandler: { [weak self] sendError in
            guard let self = self else { return }
            guard let sendError = sendError else {
                var seconds = 0
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                        seconds += 1
                        self.updateCounting(seconds: seconds)
                    })
                }
                self.receive()
                return
            }
            #if DEBUG
            print("sendError: \(sendError.localizedDescription)")
            #endif
        })
    }
    
    
    private func parseEvent(event: [String:Any]) -> NostrEvent? {
        guard let content = event["content"] as? String else { return nil }
        guard let id = event["id"] as? String else { return nil }
        guard let kind = event["kind"] as? Int else { return nil }
        guard let pubkey = event["pubkey"] as? String else { return nil }
        guard let sig = event["sig"] as? String else { return nil }
        guard let tags = event["tags"] as? [[String]] else { return nil }
        let ev = NostrEvent(content: content,
                            pubkey: pubkey,
                            kind: kind,
                            tags: tags)
        ev.sig = sig
        ev.id = id
        return ev
    }
    
    
    private func parseValidReceivedContent(content: String, completion: @escaping ((command:String?, port:Int?, requestId: String?, httpMethod: String?, param: [String:Any]?, wallet: String?)) -> Void) {
        decryptedDict(content: content) { decryptedDict in
            guard let decryptedDict = decryptedDict else { completion((nil,nil,nil,nil,nil,nil)); return }
            
            #if DEBUG
            print("decryptedDict: \(decryptedDict)")
            #endif
            
            let command = decryptedDict["command"] as? String
            let port = decryptedDict["port"] as? Int
            let http_method = decryptedDict["http_method"] as? String
            let request_id = decryptedDict["request_id"] as? String
            let param = decryptedDict["param"] as? [String:Any]
            let wallet = decryptedDict["wallet"] as? String
            completion((command, port, request_id, http_method, param, wallet))
        }
    }
    
    
    private func decryptedDict(content: String, completion: @escaping (([String:Any]?)) -> Void) {
        DataManager.retrieve { [weak self] creds in
            guard let self = self, let creds = creds else { return }
            
            let encryptionWords = creds["encryption_words"] as? String ?? ""
            guard let contentData = Data(base64Encoded: content),
                  let decryptedContent = Crypto.decryptNostr(contentData, encryptionWords) else {
                self.onDoneBlock!((nil, "Error decrypting content..."))
                completion((nil))
                return
            }
            guard let decryptedDict = try? JSONSerialization.jsonObject(with: decryptedContent, options : []) as? [String:Any] else {
                #if DEBUG
                print("converting to jsonData failing...")
                #endif
                completion((nil))
                return
            }
            completion((decryptedDict))
        }
        
    }
    
    
    private func updateCounting(seconds: Int) {
        if seconds == 30 {
            self.timer.invalidate()
            self.onDoneBlock!((nil, "Timed out after \(seconds) seconds, no response from your nostr relay..."))
        }
    }
    
    
    func openWebSocket(urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            self.webSocket = session.webSocketTask(with: request)
            self.opened = true
            self.webSocket?.resume()
        }
    }
    
    func closeWebSocket() {
        self.webSocket?.cancel(with: .goingAway, reason: nil)
        self.webSocket = nil
        self.opened = false
    }
    
    func pingWebsocket() {
        self.webSocket?.sendPing(pongReceiveHandler: { err in
            if err == nil {
                self.pongReceivedBlock!(true)
            } else {
                self.pongReceivedBlock!(false)
            }
        })
    }
}

extension StreamManager: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        opened = true
        writeReqEvent()
    }
    
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("didCloseWith closeCode: \(closeCode)")
        webSocket = nil
        opened = false
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("DEBUG: didCompleteWithError called: error = \(error.localizedDescription)")
            errorReceivedBlock!(error.localizedDescription)
        }
    }
    
}

