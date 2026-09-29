import SwiftUI
// Keep the property-wrapper API when building with an SDK that also exports
// the newer State macro but Command Line Tools lacks its macro plugin.
typealias ViewState<Value> = SwiftUI.State<Value>
