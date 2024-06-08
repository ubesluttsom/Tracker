//
//  TimerWidgetBundle.swift
//  TimerWidget
//
//  Created by Martin Mihle Nygaard on 04/06/2024.
//

import WidgetKit
import SwiftUI

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
        TimerWidgetLiveActivity()
    }
}
