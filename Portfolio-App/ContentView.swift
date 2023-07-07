//
//  ContentView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 16.06.23.
//

import SwiftUI


/// This is the main "Content" View
struct ContentView: View {
    
    let balls: [Ball] = [
        Ball(level: 1, name: "Info", view: AnyView(Info()),image: UIImage(),textSize: 12),
        Ball(level: 1, name: "Services", view: AnyView(ServicesView()),image: UIImage(),textSize: 12),
        Ball(level: 2, name: "Skills & Languages", view: AnyView(SkillsAndLanguagesView()),image: UIImage(),textSize: 14),
        Ball(level: 2, name: "Professional Experience", view: AnyView(ExperienceView()),image: UIImage(),textSize: 12),
        Ball(level: 2, name: "Education", view: AnyView(Education()),image: UIImage(),textSize: 15),
        Ball(level: 3, name: "About me", view: AnyView(AboutMeView()),image: UIImage(resource: .meImage1X1),textSize: 25)
    ]
    
    var body: some View {
        ZStack{
            
            BackgroundView().blur(radius: 10)
           BallViewController(balls: balls)
           
           
                   
        }
    }
}

#Preview {
    ContentView()
}
