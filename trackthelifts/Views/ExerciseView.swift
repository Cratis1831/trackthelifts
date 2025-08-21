//
//  ExerciseView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-14.
//

import SwiftUI

struct ExerciseView: View {
    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 8) {
            // Header
            GridRow {
                Text("Set")
                    .frame(width: 30, alignment: .center)
                
                Text("Previous")
                    .gridCellColumns(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("lbs")
                    .frame(width: 50, alignment: .center)
                
                Text("Reps")
                    .frame(width: 50, alignment: .center)
                
                Image(systemName: "checkmark")
                    .frame(width: 30, alignment: .center)
            }
            .font(.subheadline)
            .foregroundColor(.primary)
            .border(.red)

            // Rows
//            ForEach(0..<5) { index in
//                GridRow {
//                    ExerciseSetView(setNumber: index + 1)
//                        .padding(.vertical, 2)
//                }
//            }
        }

    }
}

#Preview {
    ExerciseView()
}
