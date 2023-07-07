//
//  ComposeEmailView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 26.06.23.
//
import SwiftUI
import MessageUI


/// This is a helper class for writing emails
class MailComposer: MFMailComposeViewController, MFMailComposeViewControllerDelegate{
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

}

