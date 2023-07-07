//
//  CVTimeLineView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//

import SwiftUI

/// This is the CVTimeLineView that visualizes an array of CV events.
struct CVTimeLineView: View {
    let events: [CVEvent] // An array of CV events
    
    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                Circle().fill(.white)
                    .frame(width:5)
                    .padding(2.5)
                
                    .background(){
                        Circle().fill(.cvDot).opacity(0.2).frame(width: 10)
                    }
                
                Circle().fill(.white)
                    .frame(width:5)
                    .padding(2.5)
                
                    .background(){
                        Circle().fill(.cvDot).opacity(0.5).frame(width: 10)
                    }
            }.padding(.leading,108)
            ForEach(events) { event in
                
                HStack {
                    
                    HStack {
                        
                        Text(event.dateRange).frame(width: 130.0)
                            .multilineTextAlignment(.trailing)
                           .padding(.leading, -15.0)
                            
                            
                        
                    }
                    .frame(width: 100.0)
                    Circle().fill(.white)
                        .frame(width:5)
                        .padding(2.5)
                        .background(){
                            Circle().fill(.cvDot).frame(width: 10)
                    }
                    Spacer()
                }
                
               
                
                HStack (alignment:.top){
                        VStack(alignment:.leading){
                            Rectangle().fill(.blue).frame(width: 5)
                                .frame(minHeight: CGFloat(35 * event.YearRange))
                        }
                        
                        HStack{
                          
                            VStack{
                                VStack(){
                                    Text(event.title)
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center).lineLimit(nil)
                                    Text(event.description)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 5)
                                    
                                    Text(event.details)
                                        .font(.caption)
                                        .fontWeight(.light)
                                        .padding(.top, 5)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(5)
                                }.padding(10)
                                    
                                   
                                    .frame(width: 175)
                                    .frame(minHeight:200)
                                    .background(content: {
                                    Color.blue
                                }).clipShape(RoundedRectangle(cornerRadius: 10))
                                    

                                Spacer()
                                
                            }
                         
                                
                            
                                
                            
                        }
                        
                  
                        
                    }.padding(.leading, 111)
                
                    
                }
            
            VStack {
                Rectangle().fill(.blue).frame(width: 5)
                    .frame(height: 5).padding(.top, 5).opacity(1)
                
                Rectangle().fill(.blue).frame(width: 5)
                    .frame(height: 5).padding(.top, 5).opacity(0.5)
                
                Rectangle().fill(.blue).frame(width: 5)
                    .frame(height: 5).padding(.top, 5).opacity(0.2)
            }.padding(.leading, 111)
            
        }.padding(.vertical, 50).frame(width:300)
    }
}
