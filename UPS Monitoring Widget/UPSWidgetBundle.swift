//
//  UPSWidgetBundle.swift
//  UPS Monitoring Widget
//

import WidgetKit
import SwiftUI

@main
struct UPSWidgetBundle: WidgetBundle {
    var body: some Widget {
        UPSSummaryWidget()
        UPSDetailWidget()
        UPSOverviewWidget()
    }
}
