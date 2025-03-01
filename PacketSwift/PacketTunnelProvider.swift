import NetworkExtension
import TFYSwiftSSRKit

class PacketTunnelProvider: NEPacketTunnelProvider {
    

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
       
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
       
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
       
        completionHandler()
    }
    
    override func wake() {
        
    }
}
