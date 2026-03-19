import SwiftUI
import EventKit
import EventKitUI

struct EventDetailView: UIViewControllerRepresentable {
    var event: EKEvent
    @Binding var events: [EKEvent]
    @Environment(\.presentationMode) var presentationMode
    var onDelete: (EKEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let eventViewController = EKEventViewController()
        eventViewController.event = event
        eventViewController.allowsEditing = true
        eventViewController.allowsCalendarPreview = true
        eventViewController.delegate = context.coordinator

        let navigationController = UINavigationController(rootViewController: eventViewController)

        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, EKEventViewDelegate {
        var parent: EventDetailView

        init(_ parent: EventDetailView) {
            self.parent = parent
        }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            switch action {
            case .done:
                // Handle done action if needed
                print("Done button tapped")
            case .deleted:
                // Handle deletion if needed
                print("Event deleted")
                parent.onDelete(parent.event)
            default:
                break
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
