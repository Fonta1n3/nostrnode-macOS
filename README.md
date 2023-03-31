# nostrnode-macOS

Your node, on nostr!

Nostrnode makes connecting to your own node easy.
A native swiftUI app, requires macOS 13.0.

### How to use it
Run Bitcoin Core and nostrnode on your Mac and Fully Noded on iPhone.

1. Configure nostrnode:
- Input rpc credentials, the Bitcoin network, a nostr relay url, the encryption words and the public key from Fully Noded (to subscribe to it).

2. Configure Fully Noded:
- In Fully Noded add the nostrnode public key (to subscribe to nostrnode).

### How it works
localhost <--(cleartext)--> nostrnode <--(encrypted comms)--> nostr relay <--(encrypted comms)--> Fully Noded





