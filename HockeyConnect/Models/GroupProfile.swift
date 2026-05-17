import Foundation
import FirebaseFirestore

struct GroupProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var groupName: String
    var rinkName: String
    var rinkAddress: String
}
