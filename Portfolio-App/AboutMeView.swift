//
//  AboutMe.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 20.06.23.
//

import SwiftUI
import MessageUI
import SafariServices


/// This is the About Me View
struct AboutMeView: View {
    @State var result: Result<MFMailComposeResult, Error>? = nil
    @State private var isShowingMailComposer = false
    var body: some View
    { ZStack {
        
        ScrollView {
            
            StickyHeader ()
            { Color.black
                ZStack {
                    Color.black
                    HStack{

                        ZStack {
                            
                            Color.black
                            
                            HStack {
                                Spacer(minLength: 200)
                                VStack {
                                    Spacer()
                                    Image("MeImage")
                                        .resizable(resizingMode: .stretch)
                                        .aspectRatio(contentMode: .fit)
                                    .frame(height: /*@START_MENU_TOKEN@*/200.0/*@END_MENU_TOKEN@*/)
                                }
                                   
                            }
                            
                            HStack {
                                VStack {
                                    TypewriterTextAnimation(text: "I'm Pascal Fischer")
                                        .font(.title)
                                        .foregroundColor(Color.white)
                                        .padding(.leading, 11.0)
                                        
                                    Text("Developer | Consultant")
                                        .font(.caption)
                                        .foregroundColor(Color.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.leading, 11.0)
                                    
                                } .frame(width: 280)
                                    .padding(.top,50.0)
                                   

                                Spacer()
                            }
                           
                            
                        }
                        
       
                    }
                    
                }.frame(maxWidth: 400)
               
            }
     
                
         ZStack{
             BackgroundView().blur(radius: 40)
             LinearGradient(
                gradient: Gradient(colors: [Color.primaryTile.opacity(0.9), Color.clear]),
                 startPoint: .top,
                 endPoint: .bottom
             )
             VStack{
                 
                 TileDetailsView(title: "Contact Me"){
                     VStack {
                        
                             ScrollView(.horizontal, showsIndicators: true){
                                 HStack {
                                     VStack{
                                         Image(systemName: "phone.circle.fill")
                                             .resizable(resizingMode: .stretch)
                                             .aspectRatio(contentMode: .fit)
                                             .padding(5.0)
                                             .frame(width: 70.0, height: 70.0)
                                         
                                     }.clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/).onTapGesture {
                                         if let url = URL(string: "tel://\(+4917641888552)"), UIApplication.shared.canOpenURL(url) {
                                             UIApplication.shared.open(url)
                                         }
                                     }
                                     
                                     VStack{
                                         Image(systemName: "envelope.circle.fill")
                                             .resizable(resizingMode: .stretch)
                                             .aspectRatio(contentMode: .fit)
                                             .padding(5.0)
                                             .frame(width: 70.0, height: 70.0)
                                     }.clipShape(Circle()).onTapGesture {
                                         
                                         let mailComposer = MailComposer()
                                         mailComposer.mailComposeDelegate = mailComposer
                                         mailComposer.setToRecipients(["fischer@p-f.consulting"])
                                         if let topViewController = UIApplication.shared.windows.first?.rootViewController?.presentedViewController {
                                             topViewController.present(mailComposer, animated: true, completion: nil)
                                         }
                                         
                                         
                                     }
                                     
                                     VStack{
                                         Image(systemName: "safari.fill")
                                             .resizable(resizingMode: .stretch)
                                             .aspectRatio(contentMode: .fit)
                                             .padding(5.0)
                                             .frame(width: 70.0, height: 70.0)
                                     }.clipShape(Circle()).onTapGesture {
                                         if let url = URL(string: "https://p-f.consulting") {
                                             let safariViewController = SFSafariViewController(url: url)
                                             
                                             if let topViewController = UIApplication.shared.windows.first?.rootViewController?.presentedViewController {
                                                 topViewController.present(safariViewController, animated: true, completion: nil)
                                             }
                                         }
                                     }
                                     
                                     VStack{
                                         Image(.xing)
                                             .renderingMode(.template)
                                             .resizable(resizingMode: .stretch)
                                             .aspectRatio(contentMode: .fit)
                                             .padding(5.0)
                                             .frame(width: 70.0, height: 70.0)
                                     }.clipShape(Circle()).onTapGesture {
                                         if let url = URL(string: "https://www.xing.com/profile/Pascal_Fischer104"), UIApplication.shared.canOpenURL(url) {
                                             UIApplication.shared.open(url)
                                         }
                                     }
                                     VStack{
                                         Image(.instagram)
                                             .renderingMode(.template)
                                             .resizable(resizingMode: .stretch)
                                             .aspectRatio(contentMode: .fit)
                                             .padding(5.0)
                                             .frame(width: 70.0, height: 70.0)
                                     }.clipShape(Circle()).onTapGesture {
                                         if let url = URL(string: "https://instagram.com/instaxpg?igshid=OGQ5ZDc2ODk2ZA=="), UIApplication.shared.canOpenURL(url) {
                                             UIApplication.shared.open(url)
                                         }
                                     }
                                     VStack{
                                         Image(.githubIcon)
                                             .renderingMode(.template)
                                             .resizable(resizingMode: .stretch)
                                             .aspectRatio(contentMode: .fit)
                                             .padding(5.0)
                                             .frame(width: 70.0, height: 70.0)
                                     }.clipShape(Circle()).onTapGesture {
                                         if let url = URL(string: "https://github.com/pafis"), UIApplication.shared.canOpenURL(url) {
                                             UIApplication.shared.open(url)
                                         }
                                     }
                                     
                                 }
                                 
                             }
                                 
                             
                            
                                
                         
                            
                         
                         
                     }
                 }.frame(height: 145)
                     
                     
                 TileDetailsView(title: "About me"){
                     VStack {
                         VStack {
                             Text("Hi there! I'm Pascal Fischer,\n\na passionate software developer and consultant with years of experience in the industry. I've been programming since the young age of 11, fueling my deep passion and expertise in the field.\n\nI have successfully delivered a wide range of projects for diverse clients. With my wealth of knowledge and technical skills, I can provide strategic guidance and deliver innovative solutions that drive business growth. \n\nWith a keen eye for detail and a deep understanding of user experience, I specialize in designing and developing websites and applications that not only look great but also provide a seamless and intuitive user interface. I strive to create digital experiences that leave a lasting impact.\n\nWhen I'm not crafting code, you'll find me exploring the world through my camera lens. Photography is not just a hobby for me; it's a way to express my creativity and document the beauty around us.\n\nWith my experience and a dedication to exceeding client expectations, I'm ready to take on new challenges and help you achieve your goals.\n\nLet's bring your ideas to life.").fontWeight(.semibold).padding(10.0).padding(.vertical, 5.0)
                         }
                         .padding(.horizontal, 7.0)

                     }
                 }
                 
             }
                    
         }
         .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 30.0, topTrailing: 30.0)))
                .padding(.top, -42.0)
                .padding(.bottom, -30)
              
        }.scrollIndicators(.hidden)
    }
      
        
    }
}

#Preview {
    AboutMeView()
}



