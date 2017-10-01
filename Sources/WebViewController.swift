//
//  WebViewController.swift
//  Swiftlier
//
//  Created by Andrew J Wagner on 11/4/15.
//  Copyright © 2015 Drewag LLC. All rights reserved.
//

#if os(iOS)
import UIKit

public class WebViewController: UIViewController {
    let webView = UIWebView()

    public convenience init(URL: URL) {
        self.init()

        let request = URLRequest(url: URL)
        self.webView.loadRequest(request)
    }

    public convenience init(HTML: String) {
        self.init()

        self.webView.loadHTMLString(HTML, baseURL: nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.view.addFillingSubview(self.webView)
    }
}

#endif
