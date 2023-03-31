//
//  BitcoinCoreRPC.swift
//  nostrnode
//
//  Created by Peter Denton on 3/28/23.
//

import Foundation

class BitcoinCoreRPC {
    static let shared = BitcoinCoreRPC()
    
    private init() {}
    
    func btcRPC(method: String,
                port: String?,
                wallet: String?,
                param: [String:Any],
                requestId: String,
                rpcpass: String?,
                rpcuser: String?,
                completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        
        var walletUrl = "http://\(rpcuser ?? "user"):\(rpcpass ?? "password")@localhost:\(port ?? "18332")"
        
        if let walletName = wallet {
            walletUrl += "/wallet/" + walletName
        }
        
        guard let url = URL(string: walletUrl) else {
            completion((nil, "url error"))
            return
        }
        
        var request = URLRequest(url: url)
        var timeout = 10.0
        
        switch method {
        case "gettxoutsetinfo":
            timeout = 1000.0
            
        case "importmulti", "deriveaddresses", "loadwallet":
            timeout = 60.0
            
        default:
            break
        }
        
        let loginString = String(format: "%@:%@", rpcuser ?? "", rpcpass ?? "")
        let loginData = loginString.data(using: String.Encoding.utf8)!
        let base64LoginString = loginData.base64EncodedString()
        request.timeoutInterval = timeout
        request.httpMethod = "POST"
        request.addValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        let dict:[String:Any] = ["jsonrpc":"1.0","id":requestId,"method":method,"params":param]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            #if DEBUG
            print("converting to jsonData failing...")
            #endif
            return
        }
        
        request.httpBody = jsonData
        
        #if DEBUG
        print("url = \(url)")
        print("request: \(dict)")
        #endif
        
        let session = URLSession(configuration: .default)
        
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
            guard let urlContent = data else {
                guard let error = error else {
                    completion((nil, "Unknown error."))
                    return
                }
                completion((nil, error.localizedDescription))
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSDictionary else {
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 401:
                        completion((nil, "Looks like your rpc credentials are incorrect, please double check them. If you changed your rpc creds in your bitcoin.conf you need to restart your node for the changes to take effect."))
                    case 403:
                        completion((nil, "The bitcoin-cli \(method) command has not been added to your rpcwhitelist, add \(method) to your bitcoin.conf rpcwhitelsist, reboot Bitcoin Core and try again."))
                    default:
                        completion((nil, "Unable to decode the response from your node, http status code: \(httpResponse.statusCode)"))
                    }
                } else {
                    completion((nil, "Unable to decode the response from your node..."))
                }
                return
            }
            
            #if DEBUG
            print("json: \(json)")
            #endif
            
            guard let errorCheck = json["error"] as? NSDictionary else {
                completion((json["result"], nil))
                return
            }
            
            guard let errorMessage = errorCheck["message"] as? String else {
                completion((nil, "Uknown error from bitcoind"))
                return
            }
            
            completion((nil, errorMessage))
        }
        
        task.resume()
    }
}
