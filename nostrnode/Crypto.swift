//
//  Crypto.swift
//  nostrnode
//
//  Created by Peter Denton on 3/28/23.
//

import Foundation
import RNCryptor
import secp256k1

class Crypto {
    static func encryptNostr(_ content: Data, _ password: String) -> Data? {
        return RNCryptor.encrypt(data: content, withPassword: password.replacingOccurrences(of: " ", with: ""))
    }

    static func decryptNostr(_ content: Data, _ password: String) -> Data? {
        return try? RNCryptor.decrypt(data: content, withPassword: password.replacingOccurrences(of: " ", with: ""))
    }
    
    static var randomKey: String {
        let privateKey = try! secp256k1.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey.rawRepresentation
        return publicKey.hex
    }
    
    static var privateKey: String {
        return try! secp256k1.KeyAgreement.PrivateKey().rawRepresentation.hex
    }
    
    static func publicKey(privKey: String) -> String {
        let privateKey = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: hex_decode(privKey) ?? [])
        return privateKey.publicKey.rawRepresentation.hex
    }
}




