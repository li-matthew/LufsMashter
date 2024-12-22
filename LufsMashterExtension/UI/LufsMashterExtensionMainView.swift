//
//  LufsMashterExtensionMainView.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import SwiftUI
import Combine

struct LufsMashterExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    @ObservedObject var luffers: ObservableLufsBuffer
    //    @State private var audioBufferString: String = ""
    
    var body: some View {
        VStack {
            ParameterSlider(param: parameterTree.global.dbs)

            List(luffers.buffer, id: \.self) { row in
                Text(row.map { String(format: "%.2f", $0) }.joined(separator: ", "))
            }
        }
    }
    
    //    var viz: MetalLufs {
    //        return MetalLufs(frame: CGRect(x: 0, y: 0, width: Int(1024), height: 1024))
    //    }
}
