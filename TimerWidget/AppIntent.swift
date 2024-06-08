//
//  AppIntent.swift
//  TimerWidget
//
//  Created by Martin Mihle Nygaard on 04/06/2024.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Configure your timer widget.")

    // Example configurable parameters.
    @Parameter(title: "Event Name", default: "Event")
    var eventName: String
}
