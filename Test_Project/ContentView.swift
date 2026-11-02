//
//  ContentView.swift
//  Test_Project
//
//  Created by Nicholas Baker on 10/24/26.
//

import SwiftUI
import Charts

struct ContentView: View {

    struct Sale: Identifiable {
        let id = UUID()
        var month: String
        var revenue: Double
    }

    let data: [Sale] = [
        .init(month: "Jan", revenue: 120),
        .init(month: "Feb", revenue: 95),
    ]

  
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(0..<3) { i in
                    Chart(data) { item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Revenue", item.revenue)
                        )
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}

