//
//  ContentView.swift
//  nostrnode
//
//  Created by Peter Denton on 3/28/23.
//

import SwiftUI

struct ConfigView: View {
    @EnvironmentObject var manager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: []) private var credentials: FetchedResults<Credentials>
    
    @State private var pubkey = ""
    @State private var privkey = ""
    @State private var relay = ""
    @State private var subscriptionKey = ""
    @State private var sparkoKey = ""
    @State private var rpcUser = ""
    @State private var rpcPass = ""
    @State private var encryptionPhrase = ""
    @State private var btcNetwork = ""
    
    
    var body: some View {
        Form() {
            Section("Nostr") {
                TextField("Relay:", text: $relay)
                TextField("Subscribe to:", text: $subscriptionKey)
                TextField("Public key:", text: $pubkey)
                SecureField("Private key:", text: $privkey)
                SecureField("Encryption words:", text: $encryptionPhrase)
            }
            Section("Bitcoin Core") {
                TextField("RPC User:", text: $rpcUser)
                SecureField("RPC Password:", text: $rpcPass)
                TextField("Network:", text: $btcNetwork)
            }
            Section("Core Lightning") {
                SecureField("Sparko key:", text: $sparkoKey)
            }
        }
        .formStyle(.grouped)
        .multilineTextAlignment(.leading)
        .textFieldStyle(.roundedBorder)
        .frame(width: 700, height: nil, alignment: .leading)
        .padding()
        .onSubmit {
            credentials[0].relay_url = relay
            credentials[0].nostr_pubkey = pubkey
            credentials[0].nostr_privkey = privkey
            credentials[0].nostr_subscription = subscriptionKey
            credentials[0].btc_network = btcNetwork
            credentials[0].btc_rpcpass = rpcPass
            credentials[0].btc_rpcuser = rpcUser
            credentials[0].encryption_words = encryptionPhrase
            credentials[0].sparko_key = sparkoKey
            try? viewContext.save()
        }
        .onAppear {
            let privkeyString = Crypto.privateKey
            relay = credentials[0].relay_url ?? "ws://localhost:7000/"
            pubkey = credentials[0].nostr_pubkey ?? Crypto.publicKey(privKey: privkeyString)
            privkey = credentials[0].nostr_privkey ?? privkeyString
            subscriptionKey = credentials[0].nostr_subscription ?? ""
            btcNetwork = credentials[0].btc_network ?? "Testnet"
            rpcPass = credentials[0].btc_rpcpass ?? "user"
            rpcUser = credentials[0].btc_rpcuser ?? "password"
            encryptionPhrase = credentials[0].encryption_words ?? ""
            sparkoKey = credentials[0].sparko_key ?? ""
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var manager: DataManager
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: []) private var credentials: FetchedResults<Credentials>
    
    @State private var toggleOn = false
    @State private var circleColor: Color = .red
    @State private var bitcoinCoreCircleColor: Color = .red
    
    private func connect() {
        StreamManager.shared.openWebSocket(urlString: credentials[0].relay_url ?? "")
        StreamManager.shared.eoseReceivedBlock = { _ in
            circleColor = .green
        }
        StreamManager.shared.onDoneBlock = { nostrResponse in
            #if DEBUG
            print("nostrResponse: \(nostrResponse)")
            #endif
        }
    }
    
    private func disconnect() {
        StreamManager.shared.closeWebSocket()
        toggleOn = false
        circleColor = .red
    }
    
    private func checkRelayConnection() {
        StreamManager.shared.pingWebsocket()
        StreamManager.shared.pongReceivedBlock = { received in
            if received {
                toggleOn = true
                circleColor = .green
            } else {
                toggleOn = false
                circleColor = .red
            }
        }
    }
    
    var body: some View {
        Form {
            Section("Nostr relay") {
                HStack() {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 10, height: 10)
                    Toggle(credentials[0].relay_url ?? "", isOn: $toggleOn)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: toggleOn) { connect in
                            if connect {
                                self.connect()
                            } else {
                                self.disconnect()
                            }
                        }
                        .onAppear {
                            checkRelayConnection()
                        }
                }
            }
            Section("Bitcoin Core RPC") {
                HStack() {
                    Circle()
                        .fill(bitcoinCoreCircleColor)
                        .frame(width: 10, height: 10)
                    
                    Text("\(credentials[0].btc_network ?? "Testnet") (localhost)")
                        .onAppear {
                            var port = "18332"
                            
                            switch (credentials[0].btc_network ?? "").lowercased() {
                            case "signet", "sig":
                                port = "38332"
                            case "mainnet", "main":
                                port = "8332"
                            case "regtest", "reg":
                                port = "18443"
                            default:
                                break
                            }
                            
                            BitcoinCoreRPC.shared.btcRPC(method: "getblockchaininfo", port: port, wallet: nil, param: [:], requestId: UUID().uuidString, rpcpass: credentials[0].btc_rpcpass, rpcuser: credentials[0].btc_rpcuser) { (response, errorDesc) in
                                if response != nil {
                                    bitcoinCoreCircleColor = .green
                                } else {
                                    bitcoinCoreCircleColor = .red
                                }
                            }
                        }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ContentView: View {
    private let names = ["Home", "Config"]
    private let views:[any View] = [HomeView(), ConfigView()]
    @State private var selection: String? = "Home"
    var body: some View {
        NavigationView {
            List() {
                NavigationLink {
                    HomeView()
                } label: {
                    Text("Home")
                }
                NavigationLink {
                    ConfigView()
                } label: {
                    Text("Config")
                }
            }
            Text("Select Home to start nostrnode or Config to add credentials.")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
