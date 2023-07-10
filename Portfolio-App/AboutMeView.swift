//
//  AboutMe.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 20.06.23.
//

import MessageUI
import SafariServices
import SwiftUI

/// This is the About Me View
/// A view that displays information about the author.
struct AboutMeView: View {
    // State variable to hold the result of sending an email
    @State var result: Result<MFMailComposeResult, Error>? = nil
    // State variable to show or hide the mail composer
    @State private var isShowingMailComposer = false
    
    // The body of the view
    var body: some View {
        // A ZStack to stack views on top of each other
        ZStack {
            // A ScrollView to allow scrolling
            ScrollView {
                // A custom header view that sticks to the top of the screen
                StickyHeader {
                    // A black background color
                    Color.black
                    // A horizontal stack to hold the header content
                    HStack {
                        // A ZStack to stack views on top of each other
                        ZStack {
                            // A black background color
                            Color.black
                            // A vertical stack to hold the image
                            HStack {
                                // A spacer to push the image to the right
                                Spacer(minLength: 200)
                                // A vertical stack to hold the image
                                VStack {
                                    // A spacer to push the image to the top
                                    Spacer()
                                    // An image view with a resizable image
                                    Image("MeImage")
                                        .resizable(resizingMode: .stretch)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 200.0)
                                }
                            }
                            // A horizontal stack to hold the text content
                            HStack {
                                // A vertical stack to hold the text content
                                VStack {
                                    // A typewriter text animation with the author's name
                                    TypewriterTextAnimation(text: "I'm Pascal Fischer")
                                        .font(.title)
                                        .foregroundColor(Color.white)
                                        .padding(.leading, 11.0)
                                    // A text view with the author's title
                                    Text("Developer | Consultant")
                                        .font(.caption)
                                        .foregroundColor(Color.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.leading, 11.0)
                                }.frame(width: 280)
                                    .padding(.top, 50.0)
                                // A spacer to push the text content to the right
                                Spacer()
                            }
                        }
                    }.frame(maxWidth: 400)
                }
                // A ZStack to stack views on top of each other
                ZStack {
                    // A background view with a blur effect
                    BackgroundView().blur(radius: 40)
                    // A linear gradient to fade out the background view
                    LinearGradient(
                        gradient: Gradient(colors: [Color.primaryTile.opacity(0.9), Color.clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // A vertical stack to hold the tiles
                    VStack {
                        // A tile view with contact information
                        TileDetailsView(title: "Contact Me") {
                            VStack {
                                // A horizontal scroll view to hold the contact icons
                                ScrollView(.horizontal, showsIndicators: true) {
                                    HStack {
                                        // A circle view with a phone icon
                                        VStack {
                                            Image(systemName: "phone.circle.fill")
                                                .resizable(resizingMode: .stretch)
                                                .aspectRatio(contentMode: .fit)
                                                .padding(5.0)
                                                .frame(width: 70.0, height: 70.0)
                                        }.clipShape(Circle()).onTapGesture {
                                            // When tapped, open the phone app with the author's phone number
                                            if let url = URL(string: "tel://\(+4_917_641_888_552)"), UIApplication.shared.canOpenURL(url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                        // A circle view with an email icon
                                        VStack {
                                            Image(systemName: "envelope.circle.fill")
                                                .resizable(resizingMode: .stretch)
                                                .aspectRatio(contentMode: .fit)
                                                .padding(5.0)
                                                .frame(width: 70.0, height: 70.0)
                                        }.clipShape(Circle()).onTapGesture {
                                            // When tapped, show the mail composer with the author's email address
                                            let mailComposer = MailComposer()
                                            mailComposer.mailComposeDelegate = mailComposer
                                            mailComposer.setToRecipients(["fischer@p-f.consulting"])
                                            if let topViewController = UIApplication.shared.windows.first?.rootViewController?.presentedViewController {
                                                topViewController.present(mailComposer, animated: true, completion: nil)
                                            }
                                        }
                                        // A circle view with a Safari icon
                                        VStack {
                                            Image(systemName: "safari.fill")
                                                .resizable(resizingMode: .stretch)
                                                .aspectRatio(contentMode: .fit)
                                                .padding(5.0)
                                                .frame(width: 70.0, height: 70.0)
                                        }.clipShape(Circle()).onTapGesture {
                                            // When tapped, open the author's website in Safari
                                            if let url = URL(string: "https://p-f.consulting") {
                                                let safariViewController = SFSafariViewController(url: url)
                                                if let topViewController = UIApplication.shared.windows.first?.rootViewController?.presentedViewController {
                                                    topViewController.present(safariViewController, animated: true, completion: nil)
                                                }
                                            }
                                        }
                                        // A circle view with a Xing icon
                                        VStack {
                                            Image(.xing)
                                                .renderingMode(.template)
                                                .resizable(resizingMode: .stretch)
                                                .aspectRatio(contentMode: .fit)
                                                .padding(5.0)
                                                .frame(width: 70.0, height: 70.0)
                                        }.clipShape(Circle()).onTapGesture {
                                            // When tapped, open the author's Xing profile
                                            if let url = URL(string: "https://www.xing.com/profile/Pascal_Fischer104"), UIApplication.shared.canOpenURL(url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                        // A circle view with an Instagram icon
                                        VStack {
                                            Image(.instagram)
                                                .renderingMode(.template)
                                                .resizable(resizingMode: .stretch)
                                                .aspectRatio(contentMode: .fit)
                                                .padding(5.0)
                                                .frame(width: 70.0, height: 70.0)
                                        }.clipShape(Circle()).onTapGesture {
                                            // When tapped, open the author's Instagram profile
                                            if let url = URL(string: "https://instagram.com/instaxpg?igshid=OGQ5ZDc2ODk2ZA=="), UIApplication.shared.canOpenURL(url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                        // A circle view with a GitHub icon
                                        VStack {
                                            Image(.githubIcon)
                                                .renderingMode(.template)
                                                .resizable(resizingMode: .stretch)
                                                .aspectRatio(contentMode: .fit)
                                                .padding(5.0)
                                                .frame(width: 70.0, height: 70.0)
                                        }.clipShape(Circle()).onTapGesture {
                                            // When tapped, open the author's GitHub profile
                                            if let url = URL(string: "https://github.com/pafis"), UIApplication.shared.canOpenURL(url) {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                    }
                                }
                            }
                        }.frame(height: 145)
                        // A tile view with information about me
                        TileDetailsView(title: "About me") {
                            VStack {
                                VStack {
                                    // A text view with information about me
                                    Text("Hi there! I'm Pascal Fischer,\n\na passionate software developer and consultant with years of experience in the industry. I've been programming since the young age of 11, fueling my deep passion and expertise in the field.\n\nI have successfully delivered a wide range of projects for diverse clients. With my wealth of knowledge and technical skills, I can provide strategic guidance and deliver innovative solutions that drive business growth. \n\nWith a keen eye for detail and a deep understanding of user experience, I specialize in designing and developing websites and applications that not only look great but also provide a seamless and intuitive user interface. I strive to create digital experiences that leave a lasting impact.\n\nWhen I'm not crafting code, you'll find me exploring the world through my camera lens. Photography is not just a hobby for me; it's a way to express my creativity and document the beauty around us.\n\nWith my experience and a dedication to exceeding client expectations, I'm ready to take on new challenges and help you achieve your goals.\n\nLet's bring your ideas to life.")
                                        .fontWeight(.semibold)
                                        .padding(10.0)
                                        .padding(.vertical, 5.0)
                                }
                                .padding(.horizontal, 7.0)
                            }
                        }
                    }
                }
                // A clip shape to round the corners of the tile view
                .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 30.0, topTrailing: 30.0)))
                // Padding to adjust the position of the tile view
                .padding(.top, -42.0)
                .padding(.bottom, -30)
            }
            // Hide the scroll indicators
            .scrollIndicators(.hidden)
        }
    }
}

// A preview of the AboutMeView
#Preview {
    AboutMeView()
}