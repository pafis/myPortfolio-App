//
//  ComposeEmailView.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 26.06.23.
//
import MessageUI
import SwiftUI

/// This is a helper class for writing emails
class MailComposer: MFMailComposeViewController, MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith _: MFMailComposeResult, error _: Error?) {
        controller.dismiss(animated: true)
    }
}
