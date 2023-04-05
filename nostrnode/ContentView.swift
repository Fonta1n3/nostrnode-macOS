//
//  ContentView.swift
//  nostrnode
//
//  Created by Peter Denton on 3/28/23.
//

import SwiftUI

struct ConfigView: View {
    @State private var pubkey = ""
    @State private var privkey = ""
    @State private var relay = ""
    @State private var subscriptionKey = ""
    @State private var sparkoKey = ""
    @State private var rpcUser = ""
    @State private var rpcPass = ""
    @State private var encryptionPhrase = ""
    @State private var btcNetwork = ""
    @State private var showAlert = false
    
    func saveCoreData() {
        let dict:[String:Any] = [
            "relay_url": relay,
            "nostr_pubkey": pubkey,
            "nostr_privkey": privkey,
            "nostr_subscription": subscriptionKey,
            "btc_network": btcNetwork,
            "btc_rpcuser": rpcUser,
            "btc_rpcpass": rpcPass,
            "encryption_words": encryptionPhrase,
            "sparko_key": sparkoKey
        ]
        for (key, value) in dict {
            DataManager.update(keyToUpdate: key, newValue: value) { updated in
                print("\(key): \(value) updated: \(updated)")
            }
        }
        
    }
    
    func setValues() {
        DataManager.retrieve { creds in
            guard let creds = creds else { return }
            relay = creds["relay_url"] as? String ?? ""
            pubkey = creds["nostr_pubkey"] as? String ?? ""
            privkey = creds["nostr_privkey"] as? String ?? ""
            subscriptionKey = creds["nostr_subscription"] as? String ?? ""
            btcNetwork = creds["btc_network"] as? String ?? ""
            rpcUser = creds["btc_rpcuser"] as? String ?? "user"
            rpcPass = creds["btc_rpcpass"] as? String ?? "password"
            encryptionPhrase = creds["encryption_words"] as? String ?? ""
            sparkoKey = creds["sparko_key"] as? String ?? ""
        }
    }
    
    var body: some View {
        HStack {
            Spacer()
            Button() {
                print("refresh")
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            Button() {
                print("delete")
            } label: {
                Image(systemName: "trash")
            }
        }
        .buttonStyle(.borderless)
        .padding()
        
        Form() {
            Section("Nostr") {
                TextField("Relay:", text: $relay)
                SecureField("Private key:", text: $privkey)
                TextField("Public key:", text: $pubkey)
                TextField("Subscribe to:", text: $subscriptionKey)
                SecureField("Encryption words:", text: $encryptionPhrase)
            }
            Section("Bitcoin Core") {
                TextField("RPC user:", text: $rpcUser)
                SecureField("RPC password:", text: $rpcPass)
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
            saveCoreData()
        }
        .onAppear {
            setValues()
        }
    }
}

struct HomeView: View {
    @State private var toggleOn = false
    @State private var showAlert = false
    @State private var noSubscribeTo = false
    @State private var errorDesc = ""
    @State private var circleColor: Color = .red
    @State private var bitcoinCoreCircleColor: Color = .red
    @State private var relay = ""
    @State private var btcNetwork = ""
    @State private var rpcUser = ""
    @State private var rpcPass = ""
    @State private var subscribeTo = ""
    @State private var encryptionWords = ""
    
    private func connect() {
        if relay != "" {
            StreamManager.shared.openWebSocket(urlString: relay)
            StreamManager.shared.eoseReceivedBlock = { eoseReceived in
                if eoseReceived {
                    circleColor = .green
                } else {
                    circleColor = .red
                    toggleOn = false
                }
            }
            StreamManager.shared.errorReceivedBlock = { errorDesc in
                circleColor = .red
                toggleOn = false
                showAlert = true
                self.errorDesc = errorDesc
            }
            StreamManager.shared.onDoneBlock = { nostrResponse in
                #if DEBUG
                print("nostrResponse: \(nostrResponse)")
                #endif
            }
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
    
    private func checkBtcConn() {
        var port = "18332"
        switch btcNetwork.lowercased() {
        case "signet", "sig":
            port = "38332"
        case "mainnet", "main":
            port = "8332"
        case "regtest", "reg":
            port = "18443"
        default:
            break
        }
        BitcoinCoreRPC.shared.btcRPC(method: "getblockchaininfo",
                                     port: port,
                                     wallet: nil,
                                     param: [:],
                                     requestId: UUID().uuidString,
                                     rpcpass: rpcPass,
                                     rpcuser: rpcUser) { (response, errorDesc) in
            if response != nil {
                bitcoinCoreCircleColor = .green
            } else {
                bitcoinCoreCircleColor = .red
            }
        }
    }
    
    private func loadValues() {
        DataManager.retrieve { creds in
            guard let creds = creds else { return }
            relay = creds["relay_url"] as? String ?? ""
            btcNetwork = creds["btc_network"] as? String ?? ""
            rpcUser = creds["btc_rpcuser"] as? String ?? "user"
            rpcPass = creds["btc_rpcpass"] as? String ?? "password"
            subscribeTo = creds["nostr_subscription"] as? String ?? ""
            encryptionWords = creds["encryption_words"] as? String ?? ""
            checkBtcConn()
        }
    }
    
    private func toggle(_ connect: Bool) {
        if connect {
            self.connect()
        } else {
            self.disconnect()
        }
    }
    
    var body: some View {
        Form {
            Section("Nostr relay") {
                HStack() {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 10, height: 10)
                        .alert(errorDesc, isPresented: $showAlert) {
                            Button("OK", role: .cancel) { }
                        }
                    Toggle(relay, isOn: $toggleOn)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                        .onChange(of: toggleOn) { connect in
                            if subscribeTo != "" && encryptionWords != "" {
                                noSubscribeTo = false
                                toggle(connect)
                            } else if subscribeTo == "" {
                                noSubscribeTo = true
                            } else if encryptionWords == "" {
                                noSubscribeTo = true
                            }
                        }
                        .alert("Go to Config and subscribe to your wallet first.", isPresented: $noSubscribeTo) {
                            Button("OK", role: .cancel) { }
                        }
                }
            }
            Section("Bitcoin Core RPC") {
                HStack() {
                    Circle()
                        .fill(bitcoinCoreCircleColor)
                        .frame(width: 10, height: 10)
                    Text("\(btcNetwork) (localhost)")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: {
            loadValues()
            checkRelayConnection()
        })
    }
}

struct ContentView: View {
    private let names = ["Home", "Config"]
    private let views:[any View] = [HomeView(), ConfigView()]
    @State private var selection: String? = "Home"
    
    private func createDefaultCreds() {
        DataManager.retrieve { creds in
            guard creds == nil else { return }
            let privkey = Crypto.privateKey
            let newCreds:[String:Any] = [
                "relay_url": "ws://localhost:7000/",
                "nostr_pubkey": Crypto.publicKey(privKey: privkey),
                "nostr_privkey": privkey,
                "btc_rpcuser": "user",
                "btc_rpcpass": "password",
                "btc_network": "Signet"
            ]
            DataManager.saveEntity(dict: newCreds) { saved in
                print("saved new nostr creds: \(saved)")
            }
        }
    }
    
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
                .onAppear {
                    createDefaultCreds()
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
