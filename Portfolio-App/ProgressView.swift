//
//  ProgressView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 29.06.23.
//

import SwiftUI

/// This is the ProgressView "Control"
struct ProgressView: View {
    @State var isAnimating = false
    @State var progress:CGFloat = 0.3
    @State var text:String = "Test"
    @State var strokeLineWidth:CGFloat = 30
    var body: some View {
        GeometryReader { geometry in
           
                ZStack{
                    Group{
                        Circle().trim(from: 0.5, to: 1).stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: strokeLineWidth))
                        Circle().trim(from:0.5, to: (isAnimating ? (0.5 + self.progress / 2) : 0.0)).stroke(Color.blue, style: StrokeStyle(lineWidth: strokeLineWidth)).animation(Animation.easeInOut(duration: 1))
                    }
                    Text(text)
                        .font(.system(size: strokeLineWidth*1.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, -geometry.size.height / 8)
                .offset(y:geometry.size.height / 8)
                .padding()
                .ignoresSafeArea()
                
                
                .onAppear() {
                    self.isAnimating = true
                }.onDisappear() {
                    self.isAnimating = false
                }
           
        }
    }
}

#Preview {
    ProgressView()
}
