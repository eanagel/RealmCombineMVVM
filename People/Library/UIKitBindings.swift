//
//  UIKitBindings.swift
//  People
//
//  Created by Ethan Nagel on 8/10/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit

extension UIControl {
    var isEnabledBinding: Binding<UIControl, Bool> { Binding(self, \.isEnabled) }
}

extension UILabel {
    var textBinding: Binding<UILabel, String?> { Binding(self, \.text) }
}

extension UIViewController {
    var titleBinding: Binding<UIViewController, String?> { Binding(self, \.title) }
}

extension UITextField {
    var textBinding: Binding<UITextField, String?> { Binding(self, \.text) }
}
