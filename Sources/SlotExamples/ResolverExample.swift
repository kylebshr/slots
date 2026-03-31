import Foundation
import Slots
import SwiftUI

struct DateResolver: SlotResolver {
    typealias Input = Date
    typealias Output = Text
    static func resolve(_ input: Date) -> Text {
        Text(input, style: .date)
    }
}

@Slots
struct EventRow<Title: View, When: View>: View {
    @Slot(.text) var title: Title
    @Slot(DateResolver.self) var when_: When

    var body: some View {
        HStack {
            title
            Spacer()
            when_
        }
    }
}

struct ResolverExample_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EventRow(title: "Birthday Party", when_: Date())
            EventRow(title: "Meeting") {
                Text("Tomorrow")
            }
        }
        .padding()
    }
}
