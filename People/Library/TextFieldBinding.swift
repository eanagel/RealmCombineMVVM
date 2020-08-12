//
//  TextFieldBinding.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit
import Combine

func *= (_ lhs: UITextField, _ rhs: TextFieldBinding) {
    lhs.delegate = rhs
    
    var captured: TextFieldBinding? = rhs
    let cancellable = AnyCancellable {
        if (captured != nil) {
            captured = nil
        }
    }
    
    BindingGroup.add(cancellable)
}

public class TextFieldBinding: ComposableDelegate<UITextFieldDelegate>, UITextFieldDelegate {
    private override init(nextDelegate: UITextFieldDelegate? = nil) {
        super.init(nextDelegate: nextDelegate)
    }
    
    private class SubjectBinding: TextFieldBinding {
        private let setValue: (String) -> Void
        
        public init<S>(_ subject: S, nextDelegate: UITextFieldDelegate? = nil) where S: Combine.Subject, S.Output == String {
            setValue = { subject.send($0) }
            super.init(nextDelegate: nextDelegate)
        }
        
        public init<S>(_ subject: S, nextDelegate: UITextFieldDelegate? = nil) where S: Combine.Subject, S.Output == String? {
            setValue = { subject.send($0) }
            super.init(nextDelegate: nextDelegate)
        }
        
        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // if the next delegate says we shouldn't change, quit now...
            
            if !(nextDelegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true) {
                return false
            }
            
            // figure out the new text...
            
            let currentText = textField.text ?? ""
            guard let stringRange = Range(range, in: currentText) else { return true }
            let newText = currentText.replacingCharacters(in: stringRange, with: string)
            
            // pass it to the subject
            
            setValue(newText)
            
            return true
        }
    }

    public class func subject<S>(_ subject: S) -> TextFieldBinding where S: Combine.Subject, S.Output == String {
        return SubjectBinding(subject)
    }
    
    public class func subject<S>(_ subject: S) -> TextFieldBinding where S: Combine.Subject, S.Output == String? {
        return SubjectBinding(subject)
    }

    public func subject<S>(_ subject: S) -> TextFieldBinding where S: Combine.Subject, S.Output == String {
        return SubjectBinding(subject, nextDelegate: self)
    }
    
    public func subject<S>(_ subject: S) -> TextFieldBinding where S: Combine.Subject, S.Output == String? {
        return SubjectBinding(subject, nextDelegate: self)
    }

    private class NextField: TextFieldBinding {
        public let nextField: UIControl

        public init(_ nextField: UIControl, nextDelegate: UITextFieldDelegate? = nil) {
            self.nextField = nextField
            super.init(nextDelegate: nextDelegate)
        }
        
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            // if next delegate doesn't want to return then we shouldn't do anything...
            
            if !(nextDelegate?.textFieldShouldReturn?(textField) ?? true) {
                return false
            }
            
            self.nextField.becomeFirstResponder()
            return true
        }
    }
    
    public static func nextField(_ nextField: UIControl) -> TextFieldBinding {
        return NextField(nextField)
    }
    
    public func nextField(_ nextField: UIControl) -> TextFieldBinding {
        return NextField(nextField, nextDelegate: self)
    }
}
